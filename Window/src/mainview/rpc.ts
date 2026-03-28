import { Electroview } from "electrobun/view";
import type { WindowRPC } from "../shared/types";

// Messages from bun process dispatched as DOM events
const rpc = Electroview.defineRPC<WindowRPC>({
    handlers: {
        requests: {},
        messages: {
            porchMessage: (data) => {
                window.dispatchEvent(
                    new CustomEvent("porch-message", { detail: data }),
                );
            },
            porchStatus: (data) => {
                window.dispatchEvent(
                    new CustomEvent("porch-status", { detail: data }),
                );
            },
        },
    },
});

export const electroview = new Electroview({ rpc });
