import { defineCatalog } from "@json-render/core";
import { defineRegistry } from "@json-render/react";
import { schema } from "@json-render/react/schema";
import { shadcnComponentDefinitions } from "@json-render/shadcn/catalog";
import { shadcnComponents } from "@json-render/shadcn";

// Catalog: declares all allowed 2D components
export const catalog = defineCatalog(schema, {
    components: {
        ...shadcnComponentDefinitions,
    },
});

// Registry: maps catalog to React implementations
export const { registry } = defineRegistry(catalog, {
    components: {
        ...shadcnComponents,
    },
});
