#!/usr/bin/env node
/**
 * Patch Pi's packaged JavaScript to carry optional freeform tool metadata.
 *
 * The upstream package currently models every tool as a JSON function tool.
 * This patch keeps that internal execution model, but teaches OpenAI Responses
 * providers to advertise marked tools as `custom` tools and to map raw custom
 * input back into the tool's JSON argument shape.
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

function replaceOneOf(path, oldTexts, newText) {
	const source = read(path);
	if (source.includes(newText)) {
		return;
	}
	const oldText = oldTexts.find((candidate) => source.includes(candidate));
	if (!oldText) {
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

const wrapperJs = file("dist/core/tools/tool-definition-wrapper.js");
replaceOnce(
	wrapperJs,
	`        parameters: definition.parameters,
        prepareArguments: definition.prepareArguments,
        executionMode: definition.executionMode,
`,
	`        parameters: definition.parameters,
        freeform: definition.freeform,
        prepareArguments: definition.prepareArguments,
        executionMode: definition.executionMode,
`,
);
replaceOnce(
	wrapperJs,
	`        parameters: tool.parameters,
        prepareArguments: tool.prepareArguments,
        executionMode: tool.executionMode,
`,
	`        parameters: tool.parameters,
        freeform: tool.freeform,
        prepareArguments: tool.prepareArguments,
        executionMode: tool.executionMode,
`,
);

const extensionTypes = file("dist/core/extensions/types.d.ts");
replaceOnce(
	extensionTypes,
	`/**
 * Tool definition for registerTool().
 */
export interface ToolDefinition<TParams extends TSchema = TSchema, TDetails = unknown, TState = any> {
`,
	`/** Provider-wire format for a freeform tool input. */
export interface FreeformToolFormat {
    type: string;
    syntax?: string;
    definition?: string;
}
/** Optional provider-wire metadata for tools whose model input is a raw string. */
export interface FreeformToolConfig<TParams extends TSchema = TSchema> {
    format: FreeformToolFormat;
    fromRawInput?: (input: string) => Static<TParams>;
    toRawInput?: (params: Static<TParams>) => string;
}
/**
 * Tool definition for registerTool().
 */
export interface ToolDefinition<TParams extends TSchema = TSchema, TDetails = unknown, TState = any> {
`,
);
replaceOnce(
	extensionTypes,
	`    /** Parameter schema (TypeBox) */
    parameters: TParams;
    /** Controls whether ToolExecutionComponent renders the standard colored shell or the tool renders its own framing. */
`,
	`    /** Parameter schema (TypeBox) */
    parameters: TParams;
    /** Optional Responses custom-tool metadata. Execution still receives JSON arguments. */
    freeform?: FreeformToolConfig<TParams>;
    /** Controls whether ToolExecutionComponent renders the standard colored shell or the tool renders its own framing. */
`,
);

const piAiTypes = file("node_modules/@earendil-works/pi-ai/dist/types.d.ts");
replaceOnce(
	piAiTypes,
	`export interface ToolCall {
    type: "toolCall";
    id: string;
    name: string;
    arguments: Record<string, any>;
    thoughtSignature?: string;
}
`,
	`export interface ToolCall {
    type: "toolCall";
    id: string;
    name: string;
    arguments: Record<string, any>;
    /** Raw input emitted by a Responses custom/freeform tool call. */
    freeformInput?: string;
    thoughtSignature?: string;
}
`,
);
replaceOnce(
	piAiTypes,
	`import type { TSchema } from "typebox";
export interface Tool<TParameters extends TSchema = TSchema> {
    name: string;
    description: string;
    parameters: TParameters;
}
`,
	`import type { Static, TSchema } from "typebox";
export interface FreeformToolFormat {
    type: string;
    syntax?: string;
    definition?: string;
}
export interface FreeformToolConfig<TParameters extends TSchema = TSchema> {
    format: FreeformToolFormat;
    fromRawInput?: (input: string) => Static<TParameters>;
    toRawInput?: (params: Static<TParameters>) => string;
}
export interface Tool<TParameters extends TSchema = TSchema> {
    name: string;
    description: string;
    parameters: TParameters;
    freeform?: FreeformToolConfig<TParameters>;
}
`,
);

const responsesShared = file("node_modules/@earendil-works/pi-ai/dist/api/openai-responses-shared.js");
replaceOnce(
	responsesShared,
	`}
// =============================================================================
// Message conversion
// =============================================================================
`,
	`}
function getFreeformTool(tools, name) {
    return tools?.find((tool) => tool.name === name && tool.freeform)?.freeform;
}
function rawInputToArguments(tools, name, input) {
    const freeform = getFreeformTool(tools, name);
    return freeform?.fromRawInput ? freeform.fromRawInput(input) : { input };
}
function argumentsToRawInput(tools, name, args) {
    const freeform = getFreeformTool(tools, name);
    if (!freeform) {
        return undefined;
    }
    if (typeof freeform.toRawInput !== "function") {
        throw new Error(\`Freeform tool \"\${name}\" cannot be replayed without toRawInput().\`);
    }
    return freeform.toRawInput(args);
}
// =============================================================================
// Message conversion
// =============================================================================
`,
);
replaceOnce(
	responsesShared,
	`    const transformedMessages = transformMessages(context.messages, model, normalizeToolCallId);
    const includeSystemPrompt = options?.includeSystemPrompt ?? true;
`,
	`    const transformedMessages = transformMessages(context.messages, model, normalizeToolCallId);
    const useFreeformTools = options?.freeformTools === true;
    const customToolCallIds = new Set();
    const includeSystemPrompt = options?.includeSystemPrompt ?? true;
`,
);
replaceOnce(
	responsesShared,
	`                    output.push({
                        type: "function_call",
                        id: itemId,
                        call_id: callId,
                        name: toolCall.name,
                        arguments: JSON.stringify(toolCall.arguments),
                    });
`,
	`                    const customInput = useFreeformTools
                        ? (toolCall.freeformInput ?? argumentsToRawInput(context.tools, toolCall.name, toolCall.arguments))
                        : undefined;
                    if (customInput !== undefined) {
                        customToolCallIds.add(callId);
                        output.push({
                            type: "custom_tool_call",
                            id: itemId,
                            call_id: callId,
                            name: toolCall.name,
                            input: sanitizeSurrogates(customInput),
                            status: "completed",
                        });
                    }
                    else {
                        output.push({
                            type: "function_call",
                            id: itemId,
                            call_id: callId,
                            name: toolCall.name,
                            arguments: JSON.stringify(toolCall.arguments),
                        });
                    }
`,
);
replaceOnce(
	responsesShared,
	`            messages.push({
                type: "function_call_output",
                call_id: callId,
                output,
            });
`,
	`            messages.push(customToolCallIds.has(callId)
                ? {
                    type: "custom_tool_call_output",
                    call_id: callId,
                    output,
                }
                : {
                    type: "function_call_output",
                    call_id: callId,
                    output,
                });
`,
);
replaceOnce(
	responsesShared,
	`export function convertResponsesTools(tools, options) {
    const strict = options?.strict === undefined ? false : options.strict;
    return tools.map((tool) => ({
        type: "function",
        name: tool.name,
        description: tool.description,
        parameters: tool.parameters, // TypeBox already generates JSON Schema
        strict,
    }));
}
`,
	`export function convertResponsesTools(tools, options) {
    const strict = options?.strict === undefined ? false : options.strict;
    const useFreeformTools = options?.freeformTools === true;
    return tools.map((tool) => {
        if (useFreeformTools && tool.freeform) {
            if (!tool.freeform.format) {
                throw new Error(\`Freeform tool \"\${tool.name}\" is missing format metadata.\`);
            }
            return {
                type: "custom",
                name: tool.name,
                description: tool.description,
                format: tool.freeform.format,
            };
        }
        return {
            type: "function",
            name: tool.name,
            description: tool.description,
            parameters: tool.parameters, // TypeBox already generates JSON Schema
            strict,
        };
    });
}
`,
);
replaceOnce(
	responsesShared,
	`            else if (item.type === "function_call") {
                currentItem = item;
                currentBlock = {
                    type: "toolCall",
                    id: \`\${item.call_id}|\${item.id}\`,
                    name: item.name,
                    arguments: {},
                    partialJson: item.arguments || "",
                };
                output.content.push(currentBlock);
                stream.push({ type: "toolcall_start", contentIndex: blockIndex(), partial: output });
            }
`,
	`            else if (item.type === "function_call") {
                currentItem = item;
                currentBlock = {
                    type: "toolCall",
                    id: \`\${item.call_id}|\${item.id}\`,
                    name: item.name,
                    arguments: {},
                    partialJson: item.arguments || "",
                };
                output.content.push(currentBlock);
                stream.push({ type: "toolcall_start", contentIndex: blockIndex(), partial: output });
            }
            else if (item.type === "custom_tool_call") {
                currentItem = item;
                const input = item.input || "";
                currentBlock = {
                    type: "toolCall",
                    id: \`\${item.call_id}|\${item.id ?? item.call_id}\`,
                    name: item.name,
                    arguments: rawInputToArguments(options?.tools, item.name, input),
                    freeformInput: input,
                };
                output.content.push(currentBlock);
                stream.push({ type: "toolcall_start", contentIndex: blockIndex(), partial: output });
            }
`,
);
replaceOnce(
	responsesShared,
	`        else if (event.type === "response.function_call_arguments.delta") {
            if (currentItem?.type === "function_call" && currentBlock?.type === "toolCall") {
`,
	`        else if (event.type === "response.custom_tool_call_input.delta") {
            if (currentItem?.type === "custom_tool_call" && currentBlock?.type === "toolCall") {
                currentBlock.freeformInput = (currentBlock.freeformInput || "") + event.delta;
                currentBlock.arguments = rawInputToArguments(options?.tools, currentBlock.name, currentBlock.freeformInput);
                stream.push({
                    type: "toolcall_delta",
                    contentIndex: blockIndex(),
                    delta: event.delta,
                    partial: output,
                });
            }
        }
        else if (event.type === "response.function_call_arguments.delta") {
            if (currentItem?.type === "function_call" && currentBlock?.type === "toolCall") {
`,
);
replaceOnce(
	responsesShared,
	`            else if (item.type === "function_call") {
                const args = currentBlock?.type === "toolCall" && currentBlock.partialJson
                    ? parseStreamingJson(currentBlock.partialJson)
                    : parseStreamingJson(item.arguments || "{}");
                let toolCall;
                if (currentBlock?.type === "toolCall") {
                    // Finalize in-place and strip the scratch buffer so replay only
                    // carries parsed arguments.
                    currentBlock.arguments = args;
                    delete currentBlock.partialJson;
                    toolCall = currentBlock;
                }
                else {
                    toolCall = {
                        type: "toolCall",
                        id: \`\${item.call_id}|\${item.id}\`,
                        name: item.name,
                        arguments: args,
                    };
                }
                currentBlock = null;
                stream.push({ type: "toolcall_end", contentIndex: blockIndex(), toolCall, partial: output });
            }
`,
	`            else if (item.type === "function_call") {
                const args = currentBlock?.type === "toolCall" && currentBlock.partialJson
                    ? parseStreamingJson(currentBlock.partialJson)
                    : parseStreamingJson(item.arguments || "{}");
                let toolCall;
                if (currentBlock?.type === "toolCall") {
                    // Finalize in-place and strip the scratch buffer so replay only
                    // carries parsed arguments.
                    currentBlock.arguments = args;
                    delete currentBlock.partialJson;
                    toolCall = currentBlock;
                }
                else {
                    toolCall = {
                        type: "toolCall",
                        id: \`\${item.call_id}|\${item.id}\`,
                        name: item.name,
                        arguments: args,
                    };
                }
                currentBlock = null;
                stream.push({ type: "toolcall_end", contentIndex: blockIndex(), toolCall, partial: output });
            }
            else if (item.type === "custom_tool_call") {
                const input = currentBlock?.type === "toolCall" && currentBlock.freeformInput !== undefined
                    ? currentBlock.freeformInput
                    : (item.input || "");
                let toolCall;
                if (currentBlock?.type === "toolCall") {
                    currentBlock.freeformInput = input;
                    currentBlock.arguments = rawInputToArguments(options?.tools, currentBlock.name, input);
                    toolCall = currentBlock;
                }
                else {
                    toolCall = {
                        type: "toolCall",
                        id: \`\${item.call_id}|\${item.id ?? item.call_id}\`,
                        name: item.name,
                        arguments: rawInputToArguments(options?.tools, item.name, input),
                        freeformInput: input,
                    };
                }
                currentBlock = null;
                stream.push({ type: "toolcall_end", contentIndex: blockIndex(), toolCall, partial: output });
            }
`,
);

const openaiResponses = file("node_modules/@earendil-works/pi-ai/dist/api/openai-responses.js");
replaceOnce(
	openaiResponses,
	`function buildParams(model, context, options) {
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
function buildParams(model, context, options) {
`,
);
replaceOnce(
	openaiResponses,
	`    const messages = convertResponsesMessages(model, context, OPENAI_TOOL_CALL_PROVIDERS);
`,
	`    const freeformTools = model.provider === "openai" || model.provider === "openai-codex";
    const messages = convertResponsesMessages(model, context, OPENAI_TOOL_CALL_PROVIDERS, { freeformTools });
`,
);
replaceOnce(
	openaiResponses,
	`        params.tools = convertResponsesTools(context.tools);
`,
	`        params.tools = convertResponsesTools(context.tools, { freeformTools });
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
replaceOnce(
	openaiResponses,
	`            await processResponsesStream(openaiStream, output, stream, model, {
                serviceTier: options?.serviceTier,
`,
	`            await processResponsesStream(openaiStream, output, stream, model, {
                tools: context.tools,
                serviceTier: options?.serviceTier,
`,
);

const azureResponses = file("node_modules/@earendil-works/pi-ai/dist/api/azure-openai-responses.js");
replaceOnce(
	azureResponses,
	`            await processResponsesStream(openaiStream, output, stream, model);
`,
	`            await processResponsesStream(openaiStream, output, stream, model, { tools: context.tools });
`,
);

const codexResponses = file("node_modules/@earendil-works/pi-ai/dist/api/openai-codex-responses.js");
replaceOnce(
	codexResponses,
	`function buildRequestBody(model, context, options) {
`,
	`function ensureHostedWebSearchTool(body) {
    const tools = Array.isArray(body.tools) ? body.tools : [];
    if (tools.some((tool) => tool?.type === "web_search" || tool?.type === "web_search_preview")) {
        body.tools = tools;
        return;
    }
    body.tools = [...tools, { type: "web_search", external_web_access: true }];
}
function buildRequestBody(model, context, options) {
`,
);
replaceOnce(
	codexResponses,
	`    const messages = convertResponsesMessages(model, context, CODEX_TOOL_CALL_PROVIDERS, {
        includeSystemPrompt: false,
    });
`,
	`    const messages = convertResponsesMessages(model, context, CODEX_TOOL_CALL_PROVIDERS, {
        includeSystemPrompt: false,
        freeformTools: true,
    });
`,
);
replaceOnce(
	codexResponses,
	`        body.tools = convertResponsesTools(context.tools, { strict: null });
`,
	`        body.tools = convertResponsesTools(context.tools, { strict: null, freeformTools: true });
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
replaceOnce(
	codexResponses,
	`            const responseItems = convertResponsesMessages(model, { messages: [output] }, CODEX_TOOL_CALL_PROVIDERS, {
                includeSystemPrompt: false,
            }).filter((item) => item.type !== "function_call_output");
`,
	`            const responseItems = convertResponsesMessages(model, { messages: [output] }, CODEX_TOOL_CALL_PROVIDERS, {
                includeSystemPrompt: false,
                freeformTools: true,
            }).filter((item) => item.type !== "function_call_output");
`,
);
replaceOnce(
	codexResponses,
	`                    }, idleTimeoutMs, websocketConnectTimeoutMs, options);
`,
	`                    }, idleTimeoutMs, websocketConnectTimeoutMs, options, context.tools);
`,
);
replaceOnce(
	codexResponses,
	`            await processStream(response, output, stream, model, options);
`,
	`            await processStream(response, output, stream, model, options, context.tools);
`,
);
replaceOneOf(
	codexResponses,
	[
		`async function processStream(response, output, stream, model, options) {
    await processResponsesStream(mapCodexEvents(parseSSE(response)), output, stream, model, {
        serviceTier: options?.serviceTier,
`,
		`async function processStream(response, output, stream, model, options) {
    await processResponsesStream(mapCodexEvents(parseSSE(response, options?.signal)), output, stream, model, {
        serviceTier: options?.serviceTier,
`,
	],
	`async function processStream(response, output, stream, model, options, tools) {
    await processResponsesStream(mapCodexEvents(parseSSE(response, options?.signal)), output, stream, model, {
        tools,
        serviceTier: options?.serviceTier,
`,
);
replaceOnce(
	codexResponses,
	`async function processWebSocketStream(url, body, headers, output, stream, model, onStart, idleTimeoutMs, websocketConnectTimeoutMs, options) {
`,
	`async function processWebSocketStream(url, body, headers, output, stream, model, onStart, idleTimeoutMs, websocketConnectTimeoutMs, options, tools) {
`,
);
replaceOnce(
	codexResponses,
	`        await processResponsesStream(startWebSocketOutputOnFirstEvent(mapCodexEvents(parseWebSocket(socket, options?.signal, idleTimeoutMs)), output, stream, onStart), output, stream, model, {
            serviceTier: options?.serviceTier,
`,
	`        await processResponsesStream(startWebSocketOutputOnFirstEvent(mapCodexEvents(parseWebSocket(socket, options?.signal, idleTimeoutMs)), output, stream, onStart), output, stream, model, {
            tools,
            serviceTier: options?.serviceTier,
`,
);
