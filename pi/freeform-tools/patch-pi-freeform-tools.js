#!/usr/bin/env node
/**
 * Patch Pi's packaged JavaScript for local runtime policy.
 *
 * Pi 0.82 has native grammar-constrained custom tools via `constrainedSampling`,
 * so this file deliberately avoids reimplementing tool-call conversion. Keep
 * the remaining patch surface narrow: local system-prompt wording and hosted
 * OpenAI web search.
 */
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const piRoot = process.argv[2];
if (!piRoot) {
	throw new Error("usage: patch-pi-freeform-tools.js PI_PACKAGE_ROOT");
}

function file(...parts) {
	return join(piRoot, ...parts);
}

function read(path) {
	return readFileSync(path, "utf8");
}

function write(path, text) {
	writeFileSync(path, text, "utf8");
}

function replaceOnce(path, oldText, newText) {
	const source = read(path);
	if (source.includes(newText)) {
		return;
	}
	if (!source.includes(oldText)) {
		throw new Error(`Could not find patch point in ${path}`);
	}
	write(path, source.replace(oldText, newText));
}

function replaceEvery(path, oldText, newText) {
	const source = read(path);
	if (!source.includes(oldText)) {
		return;
	}
	write(path, source.replaceAll(oldText, newText));
}

function deleteLinesContaining(path, needle) {
	const source = read(path);
	const next = source
		.split("\n")
		.filter((line) => !line.includes(needle))
		.join("\n");
	write(path, next);
}

const systemPromptJs = file("dist/core/system-prompt.js");
deleteLinesContaining(systemPromptJs, "bash for file operations");
replaceEvery(systemPromptJs, "Grep", "Rg");
replaceEvery(systemPromptJs, "grep", "rg");

const openaiResponses = file("node_modules/@earendil-works/pi-ai/dist/api/openai-responses.js");
replaceOnce(
	openaiResponses,
	`function buildParams(model, context, options, compat = getCompat(model), grammarToolInputProperties = createGrammarToolInputProperties(context.tools, compat.supportsOpenAIGrammarTools)) {
`,
	`function ensureHostedWebSearchTool(model, params) {
    if (model.provider !== "openai" && model.provider !== "openai-codex") {
        return;
    }
    const tools = Array.isArray(params.tools) ? params.tools : [];
    if (tools.some((tool) => tool?.type === "web_search" || tool?.type === "web_search_preview")) {
        params.tools = tools;
        return;
    }
    params.tools = [...tools, { type: "web_search", external_web_access: true }];
}
function buildParams(model, context, options, compat = getCompat(model), grammarToolInputProperties = createGrammarToolInputProperties(context.tools, compat.supportsOpenAIGrammarTools)) {
`,
);
replaceOnce(
	openaiResponses,
	`    if (model.reasoning) {
`,
	`    ensureHostedWebSearchTool(model, params);
    if (model.reasoning) {
`,
);

const codexResponses = file("node_modules/@earendil-works/pi-ai/dist/api/openai-codex-responses.js");
replaceOnce(
	codexResponses,
	`function buildRequestBody(model, context, options, cacheSessionId, grammarToolInputProperties = createGrammarToolInputProperties(context.tools, model.compat?.supportsOpenAIGrammarTools ?? false)) {
`,
	`function ensureHostedWebSearchTool(body) {
    const tools = Array.isArray(body.tools) ? body.tools : [];
    if (tools.some((tool) => tool?.type === "web_search" || tool?.type === "web_search_preview")) {
        body.tools = tools;
        return;
    }
    body.tools = [...tools, { type: "web_search", external_web_access: true }];
}
function buildRequestBody(model, context, options, cacheSessionId, grammarToolInputProperties = createGrammarToolInputProperties(context.tools, model.compat?.supportsOpenAIGrammarTools ?? false)) {
`,
);
replaceOnce(
	codexResponses,
	`    if (options?.reasoningEffort !== undefined) {
`,
	`    ensureHostedWebSearchTool(body);
    if (options?.reasoningEffort !== undefined) {
`,
);
