/**
 * Pi extension that runs a bash command in a freshly populated temp directory.
 *
 * The tool is a mechanical replacement for the common pattern of `mktemp -d`,
 * several heredocs, and a command run from the resulting directory. It leaves
 * the temporary directory in place so failures can be inspected afterward.
 */
import { mkdir, mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, isAbsolute, join, resolve, sep } from "node:path";
import { createBashTool, type AgentToolResult, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const mktempSchema = Type.Object(
	{
		files: Type.Record(
			Type.String(),
			Type.String({ description: "Contents to write to the file" }),
			{ description: "Map from relative file paths to contents" },
		),
		command: Type.String({ description: "Bash command to execute from inside the temp directory" }),
		timeout: Type.Optional(Type.Number({ description: "Timeout in seconds (optional, no default timeout)" })),
	},
	{ additionalProperties: false },
);

interface MktempDetails {
	tempDir: string;
	files: string[];
	bash?: unknown;
}

function throwIfAborted(signal: AbortSignal | undefined): void {
	if (signal?.aborted) {
		throw new Error("Operation aborted");
	}
}

function errorMessage(error: unknown): string {
	return error instanceof Error ? error.message : String(error);
}

function validateRelativeFilePath(filePath: string): string {
	if (filePath.length === 0) {
		throw new Error("File path must not be empty.");
	}
	if (filePath.includes("\0")) {
		throw new Error(`File path contains a NUL byte: ${filePath}`);
	}
	if (filePath.endsWith("/") || filePath.endsWith("\\")) {
		throw new Error(`File path must name a file, not a directory: ${filePath}`);
	}
	if (isAbsolute(filePath)) {
		throw new Error(`File path must be relative: ${filePath}`);
	}
	if (filePath.split(/[\\/]+/).includes("..")) {
		throw new Error(`File path must not contain '..': ${filePath}`);
	}

	const absolutePath = resolve("/", filePath);
	const relativePath = absolutePath.slice(1);
	if (relativePath.length === 0) {
		throw new Error(`File path must name a file: ${filePath}`);
	}
	return relativePath;
}

type ToolContent = AgentToolResult<unknown>["content"][number];

function isTextContent(content: ToolContent): content is ToolContent & { type: "text"; text: string } {
	return content.type === "text" && typeof (content as { text?: unknown }).text === "string";
}

function appendTempDirNote(content: ToolContent[], tempDir: string): ToolContent[] {
	const note = `\n\n[Temp directory left at: ${tempDir}]`;
	const textIndex = content.findIndex(isTextContent);
	if (textIndex === -1) {
		return [...content, { type: "text" as const, text: note.trimStart() }];
	}
	return content.map((item, index) => (index === textIndex && isTextContent(item) ? { ...item, text: `${item.text}${note}` } : item));
}

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "mktemp",
		label: "bash in a new temporary directory with custom files",
		description:
			"Create a fresh temporary directory, write the provided relative files into it, then execute a bash command from inside that directory. The temp directory is left behind and reported in the result. Bash output has Pi's standard bash truncation behavior.",
		promptSnippet: "Run bash in a fresh temp directory after writing provided files",
		promptGuidelines: [
			"Use mktemp for throwaway compilations, scripts, or tests that would otherwise require mktemp plus heredocs in a bash command.",
			"mktemp writes each provided file path relative to a fresh temp directory, then runs the command from that directory.",
			"mktemp leaves the temp directory behind and reports its path so outputs can be inspected after failures.",
		],
		parameters: mktempSchema,
		async execute(toolCallId, params, signal, onUpdate) {
			throwIfAborted(signal);
			const tempDir = await mkdtemp(join(tmpdir(), "pi-mktemp-"));
			const writtenFiles: string[] = [];
			const normalizedPaths = new Set<string>();

			try {
				for (const [filePath, contents] of Object.entries(params.files)) {
					throwIfAborted(signal);
					const relativePath = validateRelativeFilePath(filePath);
					if (normalizedPaths.has(relativePath)) {
						throw new Error(`Multiple file entries resolve to the same path: ${relativePath}`);
					}
					normalizedPaths.add(relativePath);

					const targetPath = resolve(tempDir, relativePath);
					if (targetPath !== tempDir && !targetPath.startsWith(`${tempDir}${sep}`)) {
						throw new Error(`File path escapes temp directory: ${filePath}`);
					}

					await mkdir(dirname(targetPath), { recursive: true });
					await writeFile(targetPath, contents);
					writtenFiles.push(relativePath);
				}

				throwIfAborted(signal);
				const bashTool = createBashTool(tempDir);
				const bashResult = await bashTool.execute(toolCallId, params, signal, onUpdate);
				const details: MktempDetails = {
					tempDir,
					files: writtenFiles,
					bash: bashResult.details,
				};

				return {
					content: appendTempDirNote(bashResult.content, tempDir),
					details,
				};
			} catch (error) {
				throw new Error(`${errorMessage(error)}\n\nTemp directory left at: ${tempDir}`);
			}
		},
	});
}
