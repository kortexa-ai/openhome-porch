import { Renderer, JSONUIProvider } from "@json-render/react";
import { registry } from "./json-render";
import type { Spec } from "@json-render/core";

interface NestedElement {
    component: string;
    props?: Record<string, any>;
    children?: NestedElement[];
}

/** Convert nested elements (ability-friendly format) to flat spec (Renderer format). */
function normalizeSpec(data: any): Spec | null {
    try {
        // Already flat format (has root + elements map)
        if (data.root && data.elements && !Array.isArray(data.elements)) {
            return data as Spec;
        }

        // Nested format — flatten
        const elements: NestedElement[] = data.elements ?? (Array.isArray(data) ? data : null);
        if (!elements) return null;

        const flat: Record<string, any> = {};
        let id = 0;

        function flatten(el: NestedElement): string {
            const elId = `el-${id++}`;
            const childIds = (el.children ?? []).map(flatten);
            flat[elId] = {
                type: el.component,
                props: el.props ?? {},
                children: childIds.length > 0 ? childIds : undefined,
            };
            return elId;
        }

        let rootId: string;
        if (elements.length === 1) {
            rootId = flatten(elements[0]);
        } else {
            const childIds = elements.map(flatten);
            rootId = `el-${id++}`;
            flat[rootId] = { type: "Stack", props: { direction: "vertical", gap: "md" }, children: childIds };
        }

        return { root: rootId, elements: flat } as unknown as Spec;
    } catch (e) {
        console.error("[JsonRender] Error:", e);
        return null;
    }
}

export default function JsonRenderView({ spec: rawSpec }: { spec: any }) {
    const spec = normalizeSpec(rawSpec);

    if (!spec) {
        return <div style={{ color: "#ef4444", fontSize: 14, padding: 20 }}>Invalid render spec</div>;
    }

    return (
        <JSONUIProvider registry={registry}>
            <div style={{ width: "100%" }}>
                <Renderer spec={spec} registry={registry} />
            </div>
        </JSONUIProvider>
    );
}
