/**
 * Pi extension that adds a literal whole-file replacement tool.
 *
 * The tool is intentionally narrower than a general refactoring engine: it
 * changes every non-overlapping literal occurrence of one string in listed
 * files, while preserving BOMs and each file's line-ending style.
 */
import { constants } from "node:fs";
import { access, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { isAbsolute, join, resolve } from "node:path";
import { type ExtensionAPI, type Theme, withFileMutationQueue } from "@earendil-works/pi-coding-agent";
import { Box, Container, Spacer, Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

const replaceAllSchema = Type.Object(
	{
		paths: Type.Array(Type.String(), {
			description: "Paths to files to edit, in order (relative or absolute)",
			minItems: 1,
		}),
		oldText: Type.String({ description: "Literal text to replace everywhere it occurs" }),
		newText: Type.String({ description: "Replacement text" }),
	},
	{ additionalProperties: false },
);

interface ReplaceOperation {
	oldStart: number;
	oldEnd: number;
	newStart: number;
	newEnd: number;
}

interface ReplaceHunk {
	oldStartLine: number;
	oldEndLine: number;
	newStartLine: number;
	newEndLine: number;
}

interface ReplaceFileDetails {
	path: string;
	replacements: number;
	diff: string;
}

interface ReplaceAllDetails {
	files: ReplaceFileDetails[];
	totalFiles: number;
	completedFiles: number;
	totalReplacements: number;
}

interface ReplaceAllResult {
	newContent: string;
	replacements: number;
	diff: string;
}

type ReplaceArgs = { paths?: unknown; oldText?: unknown; newText?: unknown };

type ReplaceRenderState = {
	callComponent?: Box;
	files?: ReplaceFileDetails[];
	completedFiles?: number;
	totalFiles?: number;
	totalReplacements?: number;
	settledError?: boolean;
};

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

function lineStarts(content: string): number[] {
	const starts = [0];
	for (let index = 0; index < content.length; index++) {
		if (content[index] === "\n") {
			starts.push(index + 1);
		}
	}
	return starts;
}

function lineIndexAtOffset(starts: number[], offset: number): number {
	let low = 0;
	let high = starts.length - 1;
	while (low <= high) {
		const mid = Math.floor((low + high) / 2);
		if (starts[mid] <= offset) {
			low = mid + 1;
		}
		else {
			high = mid - 1;
		}
	}
	return Math.max(0, high);
}

function affectedLineRange(starts: number[], start: number, end: number): { startLine: number; endLine: number } {
	const startLine = lineIndexAtOffset(starts, start);
	const endOffset = end > start ? end - 1 : start;
	return { startLine, endLine: Math.max(startLine, lineIndexAtOffset(starts, endOffset)) };
}

function trimmedLines(content: string): string[] {
	const lines = content.split("\n");
	if (lines[lines.length - 1] === "") {
		lines.pop();
	}
	return lines;
}

function generateReplaceDiff(oldContent: string, newContent: string, operations: ReplaceOperation[], contextLines = 2): string {
	const oldLines = trimmedLines(oldContent);
	const newLines = trimmedLines(newContent);
	const oldStarts = lineStarts(oldContent);
	const newStarts = lineStarts(newContent);
	const hunks: ReplaceHunk[] = [];
	for (const operation of operations) {
		const oldRange = affectedLineRange(oldStarts, operation.oldStart, operation.oldEnd);
		const newRange = affectedLineRange(newStarts, operation.newStart, operation.newEnd);
		const previous = hunks[hunks.length - 1];
		if (previous && oldRange.startLine <= previous.oldEndLine + contextLines * 2) {
			previous.oldEndLine = Math.max(previous.oldEndLine, oldRange.endLine);
			previous.newEndLine = Math.max(previous.newEndLine, newRange.endLine);
		}
		else {
			hunks.push({
				oldStartLine: oldRange.startLine,
				oldEndLine: oldRange.endLine,
				newStartLine: newRange.startLine,
				newEndLine: newRange.endLine,
			});
		}
	}

	const maxLineNum = Math.max(oldLines.length, newLines.length, 1);
	const lineNumWidth = String(maxLineNum).length;
	const output: string[] = [];
	let lastOldLine = 0;
	let lastNewLine = 0;

	const pushContext = (lineIndex: number) => {
		const lineNum = String(lineIndex + 1).padStart(lineNumWidth, " ");
		output.push(` ${lineNum} ${oldLines[lineIndex] ?? ""}`);
	};
	const pushRemoved = (lineIndex: number) => {
		const lineNum = String(lineIndex + 1).padStart(lineNumWidth, " ");
		output.push(`-${lineNum} ${oldLines[lineIndex] ?? ""}`);
	};
	const pushAdded = (lineIndex: number) => {
		const lineNum = String(lineIndex + 1).padStart(lineNumWidth, " ");
		output.push(`+${lineNum} ${newLines[lineIndex] ?? ""}`);
	};

	for (const hunk of hunks) {
		const contextStart = Math.max(lastOldLine, hunk.oldStartLine - contextLines);
		if (contextStart > lastOldLine) {
			output.push(` ${"".padStart(lineNumWidth, " ")} ...`);
		}
		for (let lineIndex = contextStart; lineIndex < hunk.oldStartLine; lineIndex++) {
			pushContext(lineIndex);
		}
		for (let lineIndex = hunk.oldStartLine; lineIndex <= hunk.oldEndLine && lineIndex < oldLines.length; lineIndex++) {
			pushRemoved(lineIndex);
		}
		for (let lineIndex = hunk.newStartLine; lineIndex <= hunk.newEndLine && lineIndex < newLines.length; lineIndex++) {
			pushAdded(lineIndex);
		}
		const contextEnd = Math.min(oldLines.length, hunk.oldEndLine + 1 + contextLines);
		for (let lineIndex = hunk.oldEndLine + 1; lineIndex < contextEnd; lineIndex++) {
			pushContext(lineIndex);
		}
		lastOldLine = contextEnd;
		lastNewLine = hunk.newEndLine + 1;
	}
	if (lastOldLine < oldLines.length || lastNewLine < newLines.length) {
		output.push(` ${"".padStart(lineNumWidth, " ")} ...`);
	}
	return output.join("\n");
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

	let newContent = "";
	let lastIndex = 0;
	const operations: ReplaceOperation[] = [];
	for (const index of occurrences) {
		newContent += content.slice(lastIndex, index);
		const newStart = newContent.length;
		newContent += normalizedNewText;
		operations.push({
			oldStart: index,
			oldEnd: index + normalizedOldText.length,
			newStart,
			newEnd: newContent.length,
		});
		lastIndex = index + normalizedOldText.length;
	}
	newContent += content.slice(lastIndex);
	if (newContent === content) {
		throw new Error(`No changes made to ${path}. The replacement produced identical content.`);
	}

	return { newContent, replacements: occurrences.length, diff: generateReplaceDiff(content, newContent, operations) };
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

function replacementSummary(replacements: number): string {
	const noun = replacements === 1 ? "occurrence" : "occurrences";
	return `${replacements} ${noun}`;
}

function summarizeDetails(details: ReplaceAllDetails): string {
	return `Replaced ${replacementSummary(details.totalReplacements)} across ${details.completedFiles}/${details.totalFiles} file(s).`;
}

function pathsFromArgs(args: ReplaceArgs | undefined): string[] | null {
	return Array.isArray(args?.paths) && args.paths.every((path) => typeof path === "string") ? args.paths : null;
}

function previewLiteral(value: unknown): string {
	if (typeof value !== "string") {
		return "[invalid arg]";
	}
	const normalized = value.replace(/\n/g, "\\n");
	return normalized.length > 80 ? `${normalized.slice(0, 77)}...` : normalized;
}

function replaceHeader(args: ReplaceArgs | undefined, theme: Theme): string {
	const paths = pathsFromArgs(args);
	if (!paths) {
		return `${theme.fg("toolTitle", theme.bold("replace"))} ${theme.fg("error", "[invalid paths]")}`;
	}
	const summary = paths.length > 0 ? ` ${theme.fg("accent", paths.slice(0, 4).join(", "))}` : "";
	const suffix = paths.length > 4 ? theme.fg("muted", `, +${paths.length - 4} more`) : "";
	return `${theme.fg("toolTitle", theme.bold("replace"))}${summary}${suffix}`;
}

function renderDiff(diff: string, theme: Theme): string {
	return diff
		.split("\n")
		.map((line) => {
			if (line.startsWith("+")) {
				return theme.fg("toolDiffAdded", line);
			}
			if (line.startsWith("-")) {
				return theme.fg("toolDiffRemoved", line);
			}
			return theme.fg("toolDiffContext", line);
		})
		.join("\n");
}

function updateReplaceCallComponent(component: Box, args: ReplaceArgs | undefined, theme: Theme, state: ReplaceRenderState, isPartial: boolean): void {
	component.setBgFn((text) =>
		state.settledError
			? theme.bg("toolErrorBg", text)
			: isPartial
				? theme.bg("toolPendingBg", text)
				: theme.bg("toolSuccessBg", text),
	);
	component.clear();
	component.addChild(new Text(replaceHeader(args, theme), 0, 0));
	component.addChild(
		new Text(
			`${theme.fg("muted", "literal")} ${theme.fg("toolDiffRemoved", previewLiteral(args?.oldText))} ${theme.fg("muted", "→")} ${theme.fg("toolDiffAdded", previewLiteral(args?.newText))}`,
			0,
			0,
		),
	);
}

function updateReplaceResultState(result: { details?: ReplaceAllDetails }, state: ReplaceRenderState): void {
	if (!result.details) {
		return;
	}
	state.files = result.details.files;
	state.completedFiles = result.details.completedFiles;
	state.totalFiles = result.details.totalFiles;
	state.totalReplacements = result.details.totalReplacements;
}

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "replace",
		label: "find and replace all literal occurrences",
		description:
			"Replace every non-overlapping literal occurrence of oldText in listed files. Regex syntax is not interpreted. Fails if oldText is empty, absent, overlapping, or the replacement would make no change. Preserves UTF-8 BOMs and each file's existing line-ending style.",
		promptSnippet: "Replace every non-overlapping literal occurrence of text in listed files",
		promptGuidelines: [
			"Use replace only when every literal occurrence of oldText in the listed files should be changed.",
			"replace matches literal text, not regular expressions.",
			"replace fails if oldText is absent or if matching occurrences overlap.",
		],
		parameters: replaceAllSchema,
		renderShell: "self",
		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			const files: ReplaceFileDetails[] = [];
			let totalReplacements = 0;
			const details = (): ReplaceAllDetails => ({
				files: [...files],
				totalFiles: params.paths.length,
				completedFiles: files.length,
				totalReplacements,
			});

			for (const path of params.paths) {
				const absolutePath = resolveToCwd(path, ctx.cwd);
				const fileDetails = await withFileMutationQueue(absolutePath, async () => {
					throwIfAborted(signal);
					try {
						await access(absolutePath, constants.R_OK | constants.W_OK);
					} catch (error) {
						throw new Error(`Could not edit file: ${path}. ${formatFileError(error)}.`);
					}

					throwIfAborted(signal);
					const rawContent = (await readFile(absolutePath)).toString("utf-8");
					const { bom, text } = stripBom(rawContent);
					const lineEnding = detectLineEnding(text);
					const normalizedContent = normalizeToLF(text);
					const result = replaceAllLiteral(path, normalizedContent, params.oldText, params.newText);
					const finalContent = bom + restoreLineEndings(result.newContent, lineEnding);

					throwIfAborted(signal);
					await writeFile(absolutePath, finalContent, "utf-8");
					throwIfAborted(signal);

					return { path, replacements: result.replacements, diff: result.diff };
				});

				files.push(fileDetails);
				totalReplacements += fileDetails.replacements;
				onUpdate?.({
					content: [{ type: "text" as const, text: summarizeDetails(details()) }],
					details: details(),
				});
			}

			const finalDetails = details();
			return {
				content: [{ type: "text" as const, text: summarizeDetails(finalDetails) }],
				details: finalDetails,
			};
		},
		renderCall(args, theme, context) {
			const state = context.state as ReplaceRenderState;
			const component = (context.lastComponent instanceof Box ? context.lastComponent : state.callComponent) ?? new Box(1, 1, (text) => text);
			state.callComponent = component;
			updateReplaceCallComponent(component, args as ReplaceArgs, theme, state, context.isPartial);
			return component;
		},
		renderResult(result, options, theme, context) {
			const state = context.state as ReplaceRenderState;
			state.settledError = context.isError;
			updateReplaceResultState(result as { details?: ReplaceAllDetails }, state);

			if (state.callComponent) {
				updateReplaceCallComponent(state.callComponent, context.args as ReplaceArgs, theme, state, options.isPartial);
			}

			const component = context.lastComponent ?? new Container();
			component.clear();

			const files = state.files ?? [];
			if (files.length > 0) {
				component.addChild(new Spacer(1));
				component.addChild(
					new Text(
						theme.fg(
							"muted",
							`Completed ${state.completedFiles ?? files.length}/${state.totalFiles ?? files.length} file(s), ${replacementSummary(state.totalReplacements ?? 0)}.`,
						),
						1,
						0,
					),
				);
				for (const file of files) {
					component.addChild(new Text(`\n${theme.fg("accent", file.path)} ${theme.fg("muted", `(${replacementSummary(file.replacements)})`)}`, 1, 0));
					component.addChild(new Text(renderDiff(file.diff, theme), 1, 0));
				}
			}

			if (context.isError) {
				const output = result.content
					.filter((block) => block.type === "text")
					.map((block) => block.text ?? "")
					.join("\n")
					.trimEnd();
				if (output.length > 0) {
					component.addChild(new Spacer(1));
					component.addChild(new Text(theme.fg("error", output), 1, 0));
				}
			}
			return component;
		},
	});
}
