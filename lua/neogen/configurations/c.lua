local extractors = require("neogen.utilities.extractors")
local nodes_utils = require("neogen.utilities.nodes")
local default_locator = require("neogen.locators.default")

local c_params = {
    retrieve = "first",
    node_type = "parameter_list",
    subtree = {
        {
            retrieve = "all",
            node_type = "parameter_declaration|variadic_parameter_declaration|optional_parameter_declaration",
            subtree = {
                { retrieve = "first", recursive = true, node_type = "identifier", extract = true },
            },
        },
    },
}
local c_function_extractor = function(node)
    local tree = {
        {
            retrieve = "first",
            node_type = "template_parameter_list",
            subtree = {
                {
                    retrieve = "first",
                    node_type = "type_parameter_declaration|variadic_type_parameter_declaration",
                    subtree = {
                        { retrieve = "all", node_type = "type_identifier", extract = true },
                    },
                },
            },
        },
        {
            retrieve = "first",
            node_type = "function_declarator",
            subtree = {
                c_params,
            },
        },
        {
            retrieve = "first",
            recursive = true,
            node_type = "function_declarator",
            extract = true,
        },
        {
            retrieve = "first",
            node_type = "compound_statement",
            subtree = {
                { retrieve = "first", node_type = "return_statement", extract = true },
            },
        },
        {
            retrieve = "first",
            node_type = "type_identifier",
            extract = true,
        },
        {
            retrieve = "first",
            node_type = "primitive_type",
            extract = true,
        },
        {
            retrieve = "first",
            node_type = "pointer_declarator",
            extract = true,
        },
        c_params,
    }

    local nodes = nodes_utils:matching_nodes_from(node, tree)
    local res = extractors:extract_from_matched(nodes)

    if nodes.function_declarator then
        local subnodes = nodes_utils:matching_nodes_from(nodes.function_declarator[1]:parent(), tree)
        local subres = extractors:extract_from_matched(subnodes)
        res = vim.tbl_deep_extend("keep", res, subres)
    end

    --- Checks if we have a return statement.
    --- If so, return { true } as we don't need to properly know the content of the node for the template
    --- @return table?
    local has_return_statement = function()
        if res.primitive_type and res.primitive_type[1] == "void" then
            return
        end
        if res.return_statement then
            -- function implementation
            return res.return_statement
        elseif res.function_declarator and (res.primitive_type or res.type_identifier) then
            if res.type_identifier then
                return { true }
            elseif res.primitive_type and res.primitive_type[1] ~= "void" or res.pointer_declarator then
                -- function prototype
                return { true }
            end
        end
        -- not found
        return nil
    end

    if node:type() == "template_declaration" then
        res.tparam = res.type_identifier
    end

    return {
        parameters = res.identifier,
        type_identifier = res.type_identifier,
        tparam = res.tparam,
        return_statement = has_return_statement(),
    }
end

local c_config = {
    parent = {
        func = {
            "function_declaration",
            "function_definition",
            "declaration",
            "field_declaration",
            "template_declaration",
        },
        file = { "translation_unit" },
    },

    data = {
        func = {
            ["function_declaration|function_definition|declaration|field_declaration|template_declaration"] = {
                ["0"] = {
                    extract = c_function_extractor,
                },
            },
        },
        file = {
            ["translation_unit"] = {
                ["0"] = {
                    extract = function()
                        return {}
                    end,
                },
            },
        },
    },

    locator = function(node_info, nodes_to_match)
        local result = default_locator(node_info, nodes_to_match)
        if not result then
            return nil
        end

        if node_info.current == nil then
            return result
        end

        -- if the function happens to be a function template we want to place
        -- the annotation before the template statement and extract the
        -- template parameters names as well
        if node_info.current:parent() == nil then
            return result
        end
        if node_info.current:parent():type() == "template_declaration" then
            return result:parent()
        end
        return result
    end,

    -- Use default granulator and generator
    granulator = nil,
    generator = nil,

    template = {
        annotation_convention = "doxygen",
        use_default_comment = false,

        doxygen = {
            { nil, "/**", { no_results = true, type = { "func", "file" } } },
            { nil, " * @file", { no_results = true, type = { "file" } } },
            { nil, " * @brief $1", { no_results = true, type = { "func", "file" } } },
            { nil, " */", { no_results = true, type = { "func", "file" } } },
            { nil, "", { no_results = true, type = { "file" } } },

            { nil, "/**", { type = { "func" } } },
            { nil, " * @brief $1", { type = { "func" } } },
            { nil, " *", { type = { "func" } } },
            { "tparam", " * @tparam %s $1" },
            { "parameters", " * @param %s $1" },
            { "return_statement", " * @return $1" },
            { nil, " */" },
        },
    },
}


return c_config
