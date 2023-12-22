local M = {}

-- Types
-- deviceOSVersion
-- deviceOSBranch
-- deviceOSBranchVersion
function M.Node(line, type)
    if type == "deviceOSBranch" then
        return {type = type, line = line, collapsed = true}
    else
        return {type = type, line = line}
    end

end

function M.renderNode(node)
    if node.type == "deviceOSBranchVersion" then
        return " - " .. node.line
    else
        return node.line
    end

end

function M.renderNodes(nodes)
    local lines = {}
    for i = 1, #nodes do
        table.insert(lines, M.renderNode(nodes[i]))
    end
    return lines
end

return M

