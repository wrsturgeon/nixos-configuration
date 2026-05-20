/**
 * Pi extension that adds a literal whole-file replacement tool.
 *
 * The tool is intentionally narrower than a general refactoring engine: it
 * changes every non-overlapping literal occurrence of one string in one file,
 * while preserving BOMs and the file's line-ending style.
 */
import { constants } from "node:fs";
import { access, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { isAbsolute, join, resolve } from "node:path";
import { type ExtensionAPI, withFileMutationQueue } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const replaceAllSchema = Type.Object(
	{
		path: Type.String({ description: "Path to the file to edit (relative or absolute)" }),
		oldText: Type.String({ description: "Literal text to replace everywhere it occurs" }),
		newText: Type.String({ description: "Replacement text" }),
	},
	{ additionalProperties: false },
);

interface ReplaceAllDetails {
	path: string;
	replacements: number;
}

interface ReplaceAllResult {
	newContent: string;
	replacements: number;
}

function normalizeAtPrefix(filePath: string): string {
	return filePath.startsWith("@") ? filePath.slice(1) : filePath;
}

function expandPath(filePath: string): string {
	const normalized = normalizeAtPrefix(filePath);
	if (normalized === "~") {
		return homedir();
	}
	if (normalized.startsWith("~/")) {
		return join(homedir(), normalized.slice(2));
	}
	return normalized;
}

function resolveToCwd(filePath: string, cwd: string): string {
	const expanded = expandPath(filePath);
	return isAbsolute(expanded) ? expanded : resolve(cwd, expanded);
}

function detectLineEnding(content: string): "\n" | "\r\n" {
	const crlfIndex = content.indexOf("\r\n");
	const lfIndex = content.indexOf("\n");
	if (lfIndex === -1 || crlfIndex === -1) {
		return "\n";
	}
	return crlfIndex < lfIndex ? "\r\n" : "\n";
}

function normalizeToLF(text: string): string {
	return text.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
}

function restoreLineEndings(text: string, lineEnding: "\n" | "\r\n"): string {
	return lineEnding === "\r\n" ? text.replace(/\n/g, "\r\n") : text;
}

function stripBom(content: string): { bom: string; text: string } {
	return content.startsWith("\uFEFF")
		? { bom: "\uFEFF", text: content.slice(1) }
		: { bom: "", text: content };
}

function findOccurrences(content: string, oldText: string): number[] {
	const occurrences: number[] = [];
	let start = 0;
	while (start <= content.length - oldText.length) {
		const index = content.indexOf(oldText, start);
		if (index === -1) {
			break;
		}
		occurrences.push(index);
		start = index + 1;
	}
	return occurrences;
}

function assertNoOverlaps(path: string, occurrences: number[], matchLength: number): void {
	for (let i = 1; i < occurrences.length; i++) {
		const previousStart = occurrences[i - 1];
		const currentStart = occurrences[i];
		if (currentStart < previousStart + matchLength) {
			throw new Error(
				`Found overlapping occurrences of oldText in ${path} at offsets ${previousStart} and ${currentStart}. Refusing to choose a replacement order.`,
			);
		}
	}
}

function replaceAllLiteral(path: string, content: string, oldText: string, newText: string): ReplaceAllResult {
	const normalizedOldText = normalizeToLF(oldText);
	const normalizedNewText = normalizeToLF(newText);
	if (normalizedOldText.length === 0) {
		throw new Error(`oldText must not be empty in ${path}.`);
	}

	const occurrences = findOccurrences(content, normalizedOldText);
	if (occurrences.length === 0) {
		throw new Error(`Could not find oldText in ${path}.`);
	}
	assertNoOverlaps(path, occurrences, normalizedOldText.length);

	let newContent = content;
	for (let i = occurrences.length - 1; i >= 0; i--) {
		const index = occurrences[i];
		newContent =
			newContent.slice(0, index) +
			normalizedNewText +
			newContent.slice(index + normalizedOldText.length);
	}
	if (newContent === content) {
		throw new Error(`No changes made to ${path}. The replacement produced identical content.`);
	}

	return { newContent, replacements: occurrences.length };
}

function throwIfAborted(signal: AbortSignal | undefined): void {
	if (signal?.aborted) {
		throw new Error("Operation aborted");
	}
}

function formatFileError(error: unknown): string {
	if (error instanceof Error) {
		const code = (error as { code?: unknown }).code;
		return typeof code === "string" ? `Error code: ${code}` : error.message;
	}
	return String(error);
}

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "replace_all",
		label: "replace all",
		description:
			"Replace every non-overlapping literal occurrence of oldText in one file. Regex syntax is not interpreted. Fails if oldText is empty, absent, overlapping, or the replacement would make no change. Preserves UTF-8 BOMs and the file's existing line-ending style.",
		promptSnippet: "Replace every non-overlapping literal occurrence of text in one file",
		promptGuidelines: [
			"Use replace_all only when every literal occurrence of oldText in one file should be changed.",
			"replace_all matches literal text, not regular expressions.",
			"replace_all fails if oldText is absent or if matching occurrences overlap.",
		],
		parameters: replaceAllSchema,
		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			const absolutePath = resolveToCwd(params.path, ctx.cwd);
			return withFileMutationQueue(absolutePath, async () => {
				throwIfAborted(signal);
				try {
					await access(absolutePath, constants.R_OK | constants.W_OK);
				} catch (error) {
					throw new Error(`Could not edit file: ${params.path}. ${formatFileError(error)}.`);
				}

				throwIfAborted(signal);
				const rawContent = (await readFile(absolutePath)).toString("utf-8");
				const { bom, text } = stripBom(rawContent);
				const lineEnding = detectLineEnding(text);
				const normalizedContent = normalizeToLF(text);
				const result = replaceAllLiteral(params.path, normalizedContent, params.oldText, params.newText);
				const finalContent = bom + restoreLineEndings(result.newContent, lineEnding);

				throwIfAborted(signal);
				await writeFile(absolutePath, finalContent, "utf-8");
				throwIfAborted(signal);

				const details: ReplaceAllDetails = {
					path: params.path,
					replacements: result.replacements,
				};
				const noun = result.replacements === 1 ? "occurrence" : "occurrences";
				return {
					content: [
						{
							type: "text" as const,
							text: `Replaced ${result.replacements} ${noun} in ${params.path}.`,
						},
					],
					details,
				};
			});
		},
	});
}
