import type { RPCSchema } from "electrobun/bun";

export type WindowRPC = {
    bun: RPCSchema<{
        requests: {};
        messages: {
            /** Forward a Porch message to the webview */
            porchMessage: { type: string; data?: any };
            /** Porch connection status changed */
            porchStatus: { connected: boolean };
        };
    }>;
    webview: RPCSchema<{
        requests: {};
        messages: {};
    }>;
};
