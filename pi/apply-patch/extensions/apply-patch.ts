/**
 * Pi extension that exposes Codex's apply_patch patch language as one tool.
 *
 * The implementation deliberately delegates patch parsing and file mutation to
 * the Codex-provided `apply_patch` executable. Pi owns only the JSON-facing
 * tool shape and the provider-side grammar hint.
 */
import { spawn } from "node:child_process";
import { type ExtensionAPI, type Theme } from "@earendil-works/pi-coding-agent";
import { Box, Container, Spacer, Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

const APPLY_PATCH_LARK_GRAMMAR = String.raw`start: begin_patch hunk+ end_patch
begin_patch: "*** Begin Patch" LF
end_patch: "*** End Patch" LF?

hunk: add_hunk | delete_hunk | update_hunk
add_hunk: "*** Add File: " filename LF add_line+
delete_hunk: "*** Delete File: " filename LF
update_hunk: "*** Update File: " filename LF change_move? change?

filename: /(.+)/
add_line: "+" /(.*)/ LF -> line

change_move: "*** Move to: " filename LF
change: (change_context | change_line)+ eof_line?
change_context: ("@@" | "@@ " /(.+)/) LF
change_line: ("+" | "-" | " ") /(.*)/ LF
eof_line: "*** End of File" LF

%import common.LF
`;

const applyPatchSchema = Type.Object(
	{
		patch: Type.String({ description: "Raw apply_patch patch body" }),
	},
	{ additionalProperties: false },
);

interface ApplyPatchDetails {
	cwd: string;
	code: number | null;
	signal: string | null;
	stdout: string;
	stderr: string;
}

type PatchArgs = { patch?: unknown; input?: unknown };

type PatchRenderState = {
	callComponent?: Box;
	settledError?: boolean;
};

function prepareApplyPatchArguments(args: unknown): { patch: string } {
	if (typeof args === "string") {
		return { patch: args };
	}
	if (args && typeof args === "object" && "input" in args && typeof args.input === "string") {
		return { patch: args.input };
	}
	return args as { patch: string };
}

function patchTextFromArgs(args: PatchArgs | undefined): string | null {
	if (typeof args?.patch === "string") {
		return args.patch;
	}
	if (typeof args?.input === "string") {
		return args.input;
	}
	return args?.patch === undefined && args?.input === undefined ? "" : null;
}

function formatProcessOutput(result: ApplyPatchDetails): string {
	const output = [result.stdout.trimEnd(), result.stderr.trimEnd()].filter((text) => text.length > 0).join("\n");
	return output.length > 0 ? output : "Patch applied.";
}

function formatFailure(result: ApplyPatchDetails): string {
	const status = result.code === null ? `signal ${result.signal ?? "unknown"}` : `exit code ${result.code}`;
	const output = formatProcessOutput(result);
	return `apply_patch failed with ${status}.\n${output}`;
}

function runApplyPatch(patch: string, cwd: string, signal: AbortSignal | undefined): Promise<ApplyPatchDetails> {
	return new Promise((resolve, reject) => {
		if (signal?.aborted) {
			reject(new Error("Operation aborted"));
			return;
		}

		const child = spawn("apply_patch", [], {
			cwd,
			stdio: ["pipe", "pipe", "pipe"],
		});

		let stdout = "";
		let stderr = "";
		let stdinError: Error | undefined;
		let settled = false;

		const abort = () => {
			child.kill("SIGTERM");
		};
		const finish = (callback: () => void) => {
			if (settled) {
				return;
			}
			settled = true;
			signal?.removeEventListener("abort", abort);
			callback();
		};

		signal?.addEventListener("abort", abort, { once: true });
		child.stdout.setEncoding("utf8");
		child.stderr.setEncoding("utf8");
		child.stdout.on("data", (chunk) => {
			stdout += chunk;
		});
		child.stderr.on("data", (chunk) => {
			stderr += chunk;
		});
		child.stdin.on("error", (error) => {
			stdinError = error;
		});
		child.on("error", (error) => {
			finish(() => reject(error));
		});
		child.on("close", (code, closeSignal) => {
			finish(() => {
				if (stdinError && code === 0) {
					reject(stdinError);
					return;
				}
				resolve({
					cwd,
					code,
					signal: closeSignal,
					stdout,
					stderr,
				});
			});
		});

		child.stdin.end(patch);
	});
}

function patchHeader(patch: string | null, theme: Theme): string {
	if (patch === null) {
		return `${theme.fg("toolTitle", theme.bold("patch"))} ${theme.fg("error", "[invalid arg]")}`;
	}

	const paths = patch
		.split("\n")
		.map((line) => {
			if (line.startsWith("*** Add File: ")) {
				return `A ${line.slice("*** Add File: ".length)}`;
			}
			if (line.startsWith("*** Update File: ")) {
				return `M ${line.slice("*** Update File: ".length)}`;
			}
			if (line.startsWith("*** Delete File: ")) {
				return `D ${line.slice("*** Delete File: ".length)}`;
			}
			if (line.startsWith("*** Move to: ")) {
				return `→ ${line.slice("*** Move to: ".length)}`;
			}
			return undefined;
		})
		.filter((path): path is string => path !== undefined);
	const summary = paths.length > 0 ? ` ${theme.fg("accent", paths.slice(0, 4).join(", "))}` : "";
	const suffix = paths.length > 4 ? theme.fg("muted", `, +${paths.length - 4} more`) : "";
	return `${theme.fg("toolTitle", theme.bold("patch"))}${summary}${suffix}`;
}

function renderPatchInput(patch: string, theme: Theme): string {
	return patch
		.split("\n")
		.map((line) => {
			if (line.startsWith("*** ")) {
				return theme.fg("accent", line);
			}
			if (line.startsWith("@@")) {
				return theme.fg("muted", line);
			}
			if (line.startsWith("+")) {
				return theme.fg("toolDiffAdded", line);
			}
			if (line.startsWith("-")) {
				return theme.fg("toolDiffRemoved", line);
			}
			if (line.startsWith(" ")) {
				return theme.fg("toolDiffContext", line);
			}
			return theme.fg("toolOutput", line);
		})
		.join("\n");
}

function boringSuccess(result: { content: Array<{ type: string; text?: string }> }, context: { isError: boolean }): boolean {
	if (context.isError) {
		return false;
	}
	const output = result.content
		.filter((block) => block.type === "text")
		.map((block) => block.text ?? "")
		.join("\n")
		.trim();
	return output === "Patch applied." || output.startsWith("Success. Updated the following files:");
}

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "patch",
		label: "patch",
		description: "Edit, write, and delete files using Codex's `apply_patch` tool.",
		promptSnippet: "Edit, write, and delete files using Codex's `apply_patch` tool (always use this instead of `edit` or `write` to avoid JSON escaping)",
		promptGuidelines: [
			"`patch` uses Codex's `apply_patch` patch language and accepts relative paths, `..`, absolute paths, and symlink paths.",
			"The model should provide raw apply_patch text as the patch argument.",
			"An apply_patch executable is also available in PATH.",
		],
		parameters: applyPatchSchema,
		constrainedSampling: {
			type: "grammar",
			variants: {
				openai_lark: APPLY_PATCH_LARK_GRAMMAR,
			},
		},
		prepareArguments: prepareApplyPatchArguments,
		renderShell: "self",
		executionMode: "sequential",
		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			const result = await runApplyPatch(params.patch, ctx.cwd, signal);
			if (signal?.aborted) {
				throw new Error("Operation aborted");
			}
			if (result.code !== 0) {
				throw new Error(formatFailure(result));
			}
			return {
				content: [
					{
						type: "text" as const,
						text: formatProcessOutput(result),
					},
				],
				details: result,
			};
		},
		renderCall(args, theme, context) {
			const state = context.state as PatchRenderState;
			const component = (context.lastComponent instanceof Box ? context.lastComponent : state.callComponent) ?? new Box(1, 1, (text) => text);
			state.callComponent = component;
			component.setBgFn((text) =>
				state.settledError
					? theme.bg("toolErrorBg", text)
					: context.isPartial
						? theme.bg("toolPendingBg", text)
						: theme.bg("toolSuccessBg", text),
			);

			const patch = patchTextFromArgs(args as PatchArgs);
			component.clear();
			component.addChild(new Text(patchHeader(patch, theme), 0, 0));
			if (patch === null) {
				component.addChild(new Spacer(1));
				component.addChild(new Text(theme.fg("error", "[invalid patch arg - expected string]"), 0, 0));
			}
			else if (patch.length > 0) {
				component.addChild(new Spacer(1));
				component.addChild(new Text(renderPatchInput(patch, theme), 0, 0));
			}
			return component;
		},
		renderResult(result, _options, theme, context) {
			const state = context.state as PatchRenderState;
			state.settledError = context.isError;

			const callComponent = state.callComponent;
			if (callComponent) {
				callComponent.setBgFn((text) => theme.bg(context.isError ? "toolErrorBg" : "toolSuccessBg", text));
			}

			const component = context.lastComponent ?? new Container();
			component.clear();
			if (boringSuccess(result, context)) {
				return component;
			}

			const output = result.content
				.filter((block) => block.type === "text")
				.map((block) => block.text ?? "")
				.join("\n")
				.trimEnd();
			if (output.length > 0) {
				component.addChild(new Spacer(1));
				component.addChild(new Text(theme.fg(context.isError ? "error" : "toolOutput", output), 1, 0));
			}
			return component;
		},
	});
}
