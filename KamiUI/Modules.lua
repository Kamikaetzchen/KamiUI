local UI = KamiUI

UI.modules = {}

function UI:NewModule(name)
    assert(type(name) == "string", "Module name must be a string")
    assert(not self.modules[name], "Module already exists: " .. name)

    local module = {
        name = name,
    }

    self.modules[name] = module

    return module
end

function UI:GetModule(name)
    return self.modules[name]
end