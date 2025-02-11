local extractors = require("neogen.utilities.extractors")
local nodes_utils = require("neogen.utilities.nodes")

return {
    parent = {
        type = { "property_declaration", "const_declaration", "foreach_statement" },
        func = { "function_definition" },
        class = { "class_declaration" },
    },
    data = {
        type = {
            ["property_declaration|const_declaration|foreach_statement"] = {
                ["0"] = {
                    extract = function(node)
                        local tree = {
                            { node_type = "property_element", retrieve = "all", extract = true },
                        }
                        local nodes = nodes_utils:matching_nodes_from(node, tree)
                        local res = extractors:extract_from_matched(nodes)
                        return res
                    end,
                },
            },
        },
        func = {
            ["function_definition"] = {
                ["0"] = {
                    extract = function(node)
                        local tree = {
                            {
                                node_type = "formal_parameters",
                                retrieve = "first",
                                subtree = {
                                    {
                                        node_type = "simple_parameter",
                                        retrieve = "all",
                                        subtree = {
                                            {
                                                node_type = "variable_name",
                                                retrieve = "all",
                                                extract = true,
                                            },
                                        },
                                    },
                                },
                            },
                            {
                                node_type = "compound_statement",
                                retrieve = "first",
                                subtree = {
                                    {
                                        retrieve = "first",
                                        node_type = "return_statement",
                                        recursive = true,
                                        extract = true,
                                    },
                                },
                            },
                        }
                        local nodes = nodes_utils:matching_nodes_from(node, tree)
                        local res = extractors:extract_from_matched(nodes)
                        return res
                    end,
                },
            },
        },
        class = {
            ["class_declaration"] = {
                ["0"] = {
                    extract = function()
                        return {}
                    end,
                },
            },
        },
    },
    template = {
        annotation_convention = "phpdoc",
        use_default_comment = false,

        phpdoc = {
            { nil, "/** @var $1 */", { no_results = true, type = { "type" } } },

            { nil, "/**", { no_results = true, type = { "func", "class" } } },
            { nil, " * $1", { no_results = true, type = { "func", "class" } } },
            { nil, " */", { no_results = true, type = { "func", "class" } } },

            { nil, "/**", { type = { "type", "func" } } },
            { nil, " * $1", { type = { "func" } } },
            { nil, " *", { type = { "func" } } },
            { "property_element", " * @var $1", { type = { "type" } } },
            { "variable_name", " * @param $1 %s $1", { type = { "func" } } },
            { "return_statement", " * @return $1", { type = { "func" } } },
            { nil, " */", { type = { "type", "func" } } },
        },
    },
}
