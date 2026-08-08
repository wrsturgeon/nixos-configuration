/** Evaluate freeform Emacs Lisp in the existing interactive Emacs daemon. */
import { execFileSync, spawn } from "node:child_process";
import { statSync } from "node:fs";
import {
	DEFAULT_MAX_BYTES,
	DEFAULT_MAX_LINES,
	truncateHead,
	type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

const EMACSCLIENT = "@EMACSCLIENT@";
const EMACS_HOME = "@EMACS_HOME@";
const INSIDE_EMACS = process.env.INSIDE_EMACS;
const TIMEOUT_MS = 1_000;
const EMACS_ENV = {
	...process.env,
	HOME: EMACS_HOME,
	XDG_RUNTIME_DIR: `/run/user/${statSync(EMACS_HOME).uid}`,
};

const elispSchema = Type.Object(
	{ source: Type.String({ description: "Emacs Lisp source to evaluate" }) },
	{ additionalProperties: false },
);

interface ElispParams {
	source: string;
}

interface DebugTarget {
	pid: number;
	signal: "SIGUSR1" | "SIGUSR2";
}

function runEmacsClient(expression: string, cwd: string): string {
	return execFileSync(EMACSCLIENT, ["--eval", expression], {
		cwd,
		encoding: "utf8",
		env: EMACS_ENV,
		timeout: TIMEOUT_MS,
	}).trim();
}

function debugTarget(cwd: string): DebugTarget {
	const result = runEmacsClient(
		"(progn (require 'debug) (list (emacs-pid) debug-on-event (length (visible-frame-list)) debugger-bury-or-kill))",
		cwd,
	);
	const match = result.match(/^\((\d+) (sigusr1|sigusr2) ([1-9]\d*) bury\)$/);
	if (!match) {
		throw new Error(`Emacs is not ready for timed evaluation: ${result}`);
	}
	return {
		pid: Number(match[1]),
		signal: match[2] === "sigusr1" ? "SIGUSR1" : "SIGUSR2",
	};
}

function elispExpression(source: string, cwd: string): string {
	const form = `(progn\n${source}\n)`;
	return `(let ((default-directory (file-name-as-directory ${JSON.stringify(cwd)})))
  (eval (read ${JSON.stringify(form)}) t))`;
}

function readBacktrace(cwd: string): string {
	const encoded = runEmacsClient(
		`(let ((buffer (get-buffer "*Backtrace*")))
  (unless buffer (error "Timed-out evaluation produced no *Backtrace* buffer"))
  (prog1
      (with-current-buffer buffer
        (base64-encode-string
         (buffer-substring-no-properties (point-min) (point-max))
         t))
    (kill-buffer buffer)))`,
		cwd,
	);
	return Buffer.from(JSON.parse(encoded), "base64").toString("utf8");
}

function truncate(output: string): string {
	const result = truncateHead(output, {
		maxBytes: DEFAULT_MAX_BYTES,
		maxLines: DEFAULT_MAX_LINES,
	});
	return result.truncated
		? `${result.content}\n\n[Output truncated to ${DEFAULT_MAX_LINES} lines or ${DEFAULT_MAX_BYTES} bytes.]`
		: result.content;
}

function runElisp(
	source: string,
	cwd: string,
	abortSignal: AbortSignal | undefined,
	onOutput: (output: string) => void,
): Promise<{ output: string; timedOut: boolean }> {
	return new Promise((resolve, reject) => {
		if (abortSignal?.aborted) {
			reject(new Error("Emacs Lisp evaluation aborted"));
			return;
		}

		const target = debugTarget(cwd);
		let finished = false;
		let interruption: "abort" | "timeout" | undefined;
		let timer: NodeJS.Timeout;
		let output = "";
		let stderr = "";
		const child = spawn(
			EMACSCLIENT,
			["--eval", elispExpression(source, cwd)],
			{ cwd, env: EMACS_ENV },
		);
		child.stdout.setEncoding("utf8");
		child.stderr.setEncoding("utf8");
		child.stdout.on("data", (chunk: string) => {
			output += chunk;
			onOutput(output);
		});
		child.stderr.on("data", (chunk: string) => {
			stderr += chunk;
			output += chunk;
			onOutput(output);
		});
		child.on("error", (error) => {
			if (finished) {
				return;
			}
			finished = true;
			clearTimeout(timer);
			abortSignal?.removeEventListener("abort", abort);
			reject(error);
		});
		child.on("close", (code) => {
			if (finished) {
				return;
			}
			finished = true;
			clearTimeout(timer);
			abortSignal?.removeEventListener("abort", abort);

			if (interruption) {
				try {
					const backtrace = readBacktrace(cwd);
					if (interruption === "abort") {
						reject(new Error("Emacs Lisp evaluation aborted"));
					} else {
						resolve({ output: backtrace, timedOut: true });
					}
				} catch (backtraceError) {
					reject(backtraceError);
				}
				return;
			}
			if (code !== 0) {
				reject(new Error(stderr.trim() || output.trim() || `emacsclient exited with code ${code}`));
				return;
			}
			resolve({ output: output.trimEnd(), timedOut: false });
		});

		const interrupt = (reason: "abort" | "timeout") => {
			if (finished || interruption) {
				return;
			}
			interruption = reason;
			clearTimeout(timer);
			abortSignal?.removeEventListener("abort", abort);
			try {
				process.kill(target.pid, target.signal);
			} catch (error) {
				finished = true;
				child.kill("SIGTERM");
				reject(error);
			}
		};

		const abort = () => {
			interrupt("abort");
		};

		timer = setTimeout(() => {
			interrupt("timeout");
		}, TIMEOUT_MS);
		abortSignal?.addEventListener("abort", abort, { once: true });
		if (abortSignal?.aborted) {
			abort();
		}
	});
}

export default function (pi: ExtensionAPI) {
	pi.on("before_agent_start", (event) => {
		if (INSIDE_EMACS === undefined) {
			return;
		}
		return {
			systemPrompt: `${event.systemPrompt}

Current runtime environment: Pi is running inside Emacs (INSIDE_EMACS=${JSON.stringify(INSIDE_EMACS)}). Emacs sets INSIDE_EMACS for subprocesses to indicate that they are running under Emacs. Leverage Emacs for work and to display useful information to the user.`,
		};
	});

	pi.registerTool({
		name: "elisp",
		label: "elisp",
		description:
			"Run raw Emacs Lisp in the interactive Emacs daemon. After one second, Emacs opens its debugger; press q there to abort and return the backtrace.",
		promptSnippet: "Run freeform Emacs Lisp in the interactive Emacs daemon",
		promptGuidelines: [
			"Call elisp with raw Emacs Lisp source as the freeform tool body.",
			"Use elisp for direct access to live Emacs buffers and state.",
			"Do not use shell commands to call emacsclient when elisp can perform the operation.",
			"When elisp opens a buffer that is not intended to remain visible to the user, close it afterward.",
		],
		parameters: elispSchema,
		freeform: {
			format: { type: "text" },
			fromRawInput: (input: string) => ({ source: input }),
			toRawInput: (params: ElispParams) => params.source,
		},
		renderCall(args, theme, _context) {
			const title = theme.fg("toolTitle", theme.bold("$ "));
			const source = args.source ?? "";
			return new Text(
				source
					.split("\n")
					.map((line, index) => `${index === 0 ? title : "  "}${theme.fg("accent", line)}`)
					.join("\n"),
				0,
				0,
			);
		},
		renderResult(result, _options, theme, context) {
			const content = result.content[0];
			const output = content?.type === "text" ? content.text : "";
			const color = context.isError ? "error" : "toolOutput";
			return new Text(
				output
					.split("\n")
					.map((line) => theme.fg(color, line))
					.join("\n"),
				0,
				0,
			);
		},
		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			const result = await runElisp(params.source, ctx.cwd, signal, (output) => {
				onUpdate?.({
					content: [{ type: "text" as const, text: truncate(output) }],
					details: { timedOut: false, timeoutMs: TIMEOUT_MS },
				});
			});
			return {
				content: [{ type: "text" as const, text: truncate(result.output) }],
				details: { timedOut: result.timedOut, timeoutMs: TIMEOUT_MS },
			};
		},
	});
}
