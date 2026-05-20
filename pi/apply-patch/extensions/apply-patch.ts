/**
 * Pi extension that exposes Codex's apply_patch patch language as one tool.
 *
 * The implementation deliberately delegates patch parsing and file mutation to
 * the Codex-provided `apply_patch` executable. Pi owns only the JSON-facing tool
 * shape used by today's providers and the optional freeform metadata used by
 * Responses providers that support custom tools.
 */
import { spawn } from "node:child_process";
import { type ExtensionAPI } from "@earendil-works/pi-coding-agent";
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

function prepareApplyPatchArguments(args: unknown): { patch: string } {
	if (typeof args === "string") {
		return { patch: args };
	}
	if (args && typeof args === "object" && "input" in args && typeof args.input === "string") {
		return { patch: args.input };
	}
	return args as { patch: string };
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

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "patch",
		label: "patch",
		description:
			"Apply a Codex apply_patch patch from the current working directory. The patch must start with *** Begin Patch and end with *** End Patch.",
		promptSnippet: "Apply a Codex apply_patch patch to add, delete, or update files",
		promptGuidelines: [
			"Use patch when a change is easiest to express as one Codex apply_patch patch.",
			"The patch argument must be the raw patch text, starting with *** Begin Patch and ending with *** End Patch.",
			"For shell compatibility, an apply_patch executable is also available in PATH.",
		],
		parameters: applyPatchSchema,
		prepareArguments: prepareApplyPatchArguments,
		freeform: {
			format: {
				type: "grammar",
				syntax: "lark",
				definition: APPLY_PATCH_LARK_GRAMMAR,
			},
			fromRawInput: (input: string) => ({ patch: input }),
			toRawInput: (params: { patch: string }) => params.patch,
		},
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
	});
}
