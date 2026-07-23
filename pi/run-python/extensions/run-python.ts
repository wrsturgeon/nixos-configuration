/**
 * Pi extension that adds a Nix-backed Python execution tool.
 *
 * The tool accepts raw Python source as its freeform input. Optional dependencies
 * are declared with a PEP 723-style script metadata block at the beginning of
 * the file and are interpreted as nixpkgs python3Packages attribute names.
 */
import { spawn } from "node:child_process";
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
	DEFAULT_MAX_BYTES,
	DEFAULT_MAX_LINES,
	formatSize,
	truncateTail,
	type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const NIXPKGS_PATH = "@NIXPKGS_PATH@";
const NIX_SYSTEM = "@NIX_SYSTEM@";
const PYTHON_PACKAGE_ATTR_PATTERN = /^[A-Za-z0-9][A-Za-z0-9_-]*$/;
const PEP723_START = "# /// script";
const PEP723_END = "# ///";

const pythonSchema = Type.Object(
	{
		script: Type.String({ description: "Python script to execute" }),
	},
	{ additionalProperties: false },
);

interface PythonParams {
	script: string;
}

interface RunPythonResult {
	stdout: string;
	stderr: string;
	exitCode: number | null;
	signal: string | null;
	aborted: boolean;
}

interface FormattedOutputs {
	text: string;
	truncated: {
		stdout: boolean;
		stderr: boolean;
	};
	files: {
		stdout?: string;
		stderr?: string;
	};
}

class TomlStringArrayParser {
	private position = 0;

	constructor(private readonly text: string) {}

	parse(): string[] {
		this.skipTrivia();
		if (this.peek() !== "[") {
			throw new Error("PEP 723 dependencies must be a TOML array of strings.");
		}
		this.position++;

		const values: string[] = [];
		while (true) {
			this.skipTrivia();
			if (this.peek() === "]") {
				this.position++;
				return values;
			}

			values.push(this.parseString());
			this.skipTrivia();

			const next = this.peek();
			if (next === ",") {
				this.position++;
				continue;
			}
			if (next === "]") {
				this.position++;
				return values;
			}
			throw new Error("PEP 723 dependencies must be a TOML array containing only strings.");
		}
	}

	private peek(): string | undefined {
		return this.text[this.position];
	}

	private skipTrivia(): void {
		while (this.position < this.text.length) {
			const char = this.text[this.position];
			if (char === " " || char === "\t" || char === "\n" || char === "\r") {
				this.position++;
				continue;
			}
			if (char === "#") {
				while (this.position < this.text.length && this.text[this.position] !== "\n") {
					this.position++;
				}
				continue;
			}
			return;
		}
	}

	private parseString(): string {
		const quote = this.peek();
		if (quote !== '"' && quote !== "'") {
			throw new Error("PEP 723 dependencies must be a TOML array containing only strings.");
		}
		if (this.text.startsWith(`${quote}${quote}${quote}`, this.position)) {
			throw new Error("PEP 723 dependencies must use single-line TOML strings.");
		}
		return quote === '"' ? this.parseBasicString() : this.parseLiteralString();
	}

	private parseBasicString(): string {
		this.position++;
		let result = "";

		while (this.position < this.text.length) {
			const char = this.text[this.position++];
			if (char === '"') {
				return result;
			}
			if (char === "\n" || char === "\r") {
				break;
			}
			if (char !== "\\") {
				result += char;
				continue;
			}

			const escaped = this.text[this.position++];
			switch (escaped) {
				case "b":
					result += "\b";
					break;
				case "t":
					result += "\t";
					break;
				case "n":
					result += "\n";
					break;
				case "f":
					result += "\f";
					break;
				case "r":
					result += "\r";
					break;
				case '"':
					result += '"';
					break;
				case "\\":
					result += "\\";
					break;
				case "u":
					result += this.parseUnicodeEscape(4);
					break;
				case "U":
					result += this.parseUnicodeEscape(8);
					break;
				default:
					throw new Error(`Unsupported TOML string escape in PEP 723 dependencies: \\${escaped ?? ""}`);
			}
		}

		throw new Error("Unterminated TOML string in PEP 723 dependencies.");
	}

	private parseLiteralString(): string {
		this.position++;
		let result = "";

		while (this.position < this.text.length) {
			const char = this.text[this.position++];
			if (char === "'") {
				return result;
			}
			if (char === "\n" || char === "\r") {
				break;
			}
			result += char;
		}

		throw new Error("Unterminated TOML string in PEP 723 dependencies.");
	}

	private parseUnicodeEscape(length: number): string {
		const hex = this.text.slice(this.position, this.position + length);
		if (!new RegExp(`^[0-9A-Fa-f]{${length}}$`).test(hex)) {
			throw new Error("Invalid Unicode escape in PEP 723 dependencies.");
		}
		this.position += length;
		return String.fromCodePoint(Number.parseInt(hex, 16));
	}
}

function nixStringLiteral(value: string): string {
	return `"${value.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n")}"`;
}

function normalizeLineEndings(text: string): string {
	return text.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
}

function isEncodingComment(line: string | undefined): boolean {
	return line !== undefined && /^#.*coding[:=]\s*[-\w.]+/.test(line);
}

function extractPep723Toml(script: string): string | undefined {
	const lines = normalizeLineEndings(script).split("\n");
	if (lines[0]?.startsWith("\uFEFF")) {
		lines[0] = lines[0].slice(1);
	}

	let index = 0;
	if (lines[index]?.startsWith("#!")) {
		index++;
	}
	if (isEncodingComment(lines[index])) {
		index++;
	}
	while (lines[index]?.trim() === "") {
		index++;
	}

	if ((lines[index] ?? "").trimEnd() !== PEP723_START) {
		return undefined;
	}

	const content: string[] = [];
	for (index++; index < lines.length; index++) {
		const line = lines[index];
		if (line.trimEnd() === PEP723_END) {
			return content.join("\n");
		}
		if (!line.startsWith("#")) {
			throw new Error("Invalid PEP 723 script metadata block: metadata lines must start with '#'.");
		}
		content.push(line.startsWith("# ") ? line.slice(2) : line.slice(1));
	}

	throw new Error("Unterminated PEP 723 script metadata block: missing '# ///'.");
}

function stripTomlComment(line: string): string {
	let quote: '"' | "'" | undefined;
	for (let index = 0; index < line.length; index++) {
		const char = line[index];
		if (quote !== undefined) {
			if (quote === '"' && char === "\\") {
				index++;
				continue;
			}
			if (char === quote) {
				quote = undefined;
			}
			continue;
		}

		if (char === "#") {
			return line.slice(0, index);
		}
		if (char === '"' || char === "'") {
			quote = char;
		}
	}
	return line;
}

function findTopLevelDependenciesValueSource(toml: string): string | undefined {
	const lines = toml.split("\n");
	let offset = 0;
	let insideTable = false;

	for (const line of lines) {
		const uncommented = stripTomlComment(line).trim();
		if (uncommented.length === 0) {
			offset += line.length + 1;
			continue;
		}
		if (uncommented.startsWith("[")) {
			insideTable = true;
			offset += line.length + 1;
			continue;
		}
		if (!insideTable && /^dependencies\s*=/.test(uncommented)) {
			const equalsIndex = line.indexOf("=");
			return toml.slice(offset + equalsIndex + 1);
		}
		offset += line.length + 1;
	}

	return undefined;
}

function parsePep723Dependencies(script: string): string[] {
	const toml = extractPep723Toml(script);
	if (toml === undefined) {
		return [];
	}

	const valueSource = findTopLevelDependenciesValueSource(toml);
	if (valueSource === undefined) {
		return [];
	}

	return new TomlStringArrayParser(valueSource).parse();
}

function normalizePackages(packages: string[]): string[] {
	const normalized: string[] = [];
	const seen = new Set<string>();

	for (const [index, packageName] of packages.entries()) {
		if (!PYTHON_PACKAGE_ATTR_PATTERN.test(packageName)) {
			throw new Error(
				`Invalid PEP 723 dependencies[${index}] value ${JSON.stringify(packageName)}. Dependencies are interpreted as Nix python3Packages attribute names, so use names like "requests", "numpy", or "beautifulsoup4"; version specifiers and raw Nix expressions are not accepted.`,
			);
		}
		if (seen.has(packageName)) {
			continue;
		}
		seen.add(packageName);
		normalized.push(packageName);
	}

	return normalized;
}

function preparePythonArguments(args: unknown): PythonParams {
	if (typeof args === "string") {
		return { script: args };
	}
	if (args && typeof args === "object") {
		const input = args as { input?: unknown; script?: unknown };
		if (typeof input.input === "string") {
			return { script: input.input };
		}
		if (typeof input.script === "string") {
			return { script: input.script };
		}
	}
	return args as PythonParams;
}

function buildNixExpression(packageNames: string[]): string {
	const packageExpressions = packageNames.map((packageName) => `(builtins.getAttr ${nixStringLiteral(packageName)} ps)`);
	const packageList = packageExpressions.length === 0 ? "" : `\n  ${packageExpressions.join("\n  ")}\n`;

	return `let
  pkgs = import ${nixStringLiteral(NIXPKGS_PATH)} { system = ${nixStringLiteral(NIX_SYSTEM)}; };
in
pkgs.python3.withPackages (ps: [${packageList}])`;
}

function buildNixArgs(packageNames: string[]): string[] {
	return [
		"shell",
		"--quiet",
		"--impure",
		"--expr",
		buildNixExpression(packageNames),
		"--command",
		"python",
		"-s",
		"-",
	];
}

function throwIfAborted(signal: AbortSignal | undefined): void {
	if (signal?.aborted) {
		throw new Error("Python execution aborted");
	}
}

function runPython(script: string, packageNames: string[], cwd: string, signal: AbortSignal | undefined) {
	return new Promise<RunPythonResult>((resolve, reject) => {
		const env = { ...process.env, PYTHONNOUSERSITE: "1" };
		delete env.PYTHONHOME;
		delete env.PYTHONPATH;

		const child = spawn("nix", buildNixArgs(packageNames), {
			cwd,
			env,
			stdio: ["pipe", "pipe", "pipe"],
		});

		let stdout = "";
		let stderr = "";
		let finished = false;
		let aborted = false;
		let killTimer: NodeJS.Timeout | undefined;

		const cleanup = () => {
			if (killTimer !== undefined) {
				clearTimeout(killTimer);
			}
			signal?.removeEventListener("abort", abort);
		};

		const finish = (callback: () => void) => {
			if (finished) {
				return;
			}
			finished = true;
			cleanup();
			callback();
		};

		const abort = () => {
			aborted = true;
			child.kill("SIGTERM");
			killTimer = setTimeout(() => {
				child.kill("SIGKILL");
			}, 2_000);
			killTimer.unref?.();
		};

		child.stdout.setEncoding("utf8");
		child.stdout.on("data", (chunk: string) => {
			stdout += chunk;
		});

		child.stderr.setEncoding("utf8");
		child.stderr.on("data", (chunk: string) => {
			stderr += chunk;
		});

		child.stdin.on("error", () => {
			// If Nix fails before Python starts, stdin can close early. The real
			// failure still arrives on stderr and via the process exit code.
		});

		child.on("error", (error) => {
			finish(() => reject(error));
		});

		child.on("close", (exitCode, termSignal) => {
			finish(() =>
				resolve({
					stdout,
					stderr,
					exitCode,
					signal: termSignal,
					aborted,
				}),
			);
		});

		if (signal?.aborted) {
			abort();
		} else {
			signal?.addEventListener("abort", abort, { once: true });
		}

		child.stdin.end(script);
	});
}

function statusText(result: RunPythonResult): string {
	if (result.signal !== null) {
		return `signal ${result.signal}`;
	}
	if (result.exitCode !== null) {
		return `exit code ${result.exitCode}`;
	}
	return "unknown exit status";
}

async function formatOutputs(stdout: string, stderr: string): Promise<FormattedOutputs> {
	let tempDir: string | undefined;
	const files: FormattedOutputs["files"] = {};
	const truncated = { stdout: false, stderr: false };

	const writeFullOutput = async (streamName: "stdout" | "stderr", output: string): Promise<string> => {
		tempDir ??= await mkdtemp(join(tmpdir(), "pi-run-python-"));
		const path = join(tempDir, `${streamName}.txt`);
		await writeFile(path, output, "utf8");
		files[streamName] = path;
		return path;
	};

	const formatSection = async (streamName: "stdout" | "stderr", output: string): Promise<string | undefined> => {
		if (output.length === 0) {
			return undefined;
		}

		const truncation = truncateTail(output, {
			maxBytes: DEFAULT_MAX_BYTES,
			maxLines: DEFAULT_MAX_LINES,
		});
		truncated[streamName] = truncation.truncated;

		let text = `${streamName}:\n${truncation.content}`;
		if (truncation.truncated) {
			const fullOutputPath = await writeFullOutput(streamName, output);
			text += `\n\n[${streamName} truncated: ${truncation.outputLines} of ${truncation.totalLines} lines (${formatSize(truncation.outputBytes)} of ${formatSize(truncation.totalBytes)}). Full output saved to: ${fullOutputPath}]`;
		}
		return text;
	};

	const sections = [await formatSection("stdout", stdout), await formatSection("stderr", stderr)].filter(
		(section): section is string => section !== undefined,
	);

	return {
		text: sections.length === 0 ? "No stdout or stderr output." : sections.join("\n\n"),
		truncated,
		files,
	};
}

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "run-python",
		label: "run-python",
		description:
			"Run a raw Python 3 script supplied as the freeform tool body, not as JSON. To request extra packages, put a PEP 723 script metadata block at the beginning of the file, for example `# /// script`, then `# dependencies = [\"requests\"]`, then `# ///`. Dependency strings are interpreted as Nix python3Packages attribute names and installed with python3.withPackages; PyPI/uv version specifiers and raw Nix expressions are not accepted. If there is no metadata block or no dependencies field, the script runs with the standard library only. Output is truncated to 50KB or 2000 lines per stream, whichever is hit first.",
		promptSnippet: "Run a freeform Python script with automatic dependency installation (always use this instead of `python3 - <<'PY' ...`)",
		promptGuidelines: [
			"Call the `run-python` tool as a freeform tool: the entire tool input is Python source, not JSON.",
			"Use a PEP 723 header at the beginning of the script when dependencies are needed: `# /// script`, commented TOML with `dependencies = [...]`, then `# ///`.",
			"Dependencies are Nix `python3Packages` attribute names such as `requests`, `numpy`, or `beautifulsoup4`; do not use pip install commands, uv version specifiers, or raw Nix expressions.",
			"Omit the PEP 723 header, or omit its dependencies field, when the Python standard library is enough.",
		],
		parameters: pythonSchema,
		prepareArguments: preparePythonArguments,
		freeform: {
			format: { type: "text" },
			fromRawInput: (input: string) => ({ script: input }),
			toRawInput: (params: PythonParams) => params.script,
		},
		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			throwIfAborted(signal);
			const packageNames = normalizePackages(parsePep723Dependencies(params.script));
			const result = await runPython(params.script, packageNames, ctx.cwd, signal);
			throwIfAborted(signal);

			const formattedOutputs = await formatOutputs(result.stdout, result.stderr);
			const details = {
				dependencies: packageNames,
				exitCode: result.exitCode,
				signal: result.signal,
				truncated: formattedOutputs.truncated,
				files: formattedOutputs.files,
			};

			if (result.aborted) {
				throw new Error("Python execution aborted");
			}

			if (result.exitCode !== 0 || result.signal !== null) {
				throw new Error(`Python command failed with ${statusText(result)}.\n\n${formattedOutputs.text}`);
			}

			return {
				content: [{ type: "text" as const, text: formattedOutputs.text }],
				details,
			};
		},
	});
}
