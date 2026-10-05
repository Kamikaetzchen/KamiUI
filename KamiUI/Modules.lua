local UI = KamiUI

UI.modules = {}

function UI:NewModule(name, addonName)
    assert(type(name) == "string", "Module name must be a string")
    assert(not self.modules[name], "Module already exists: " .. name)

    local module = {
        name = name,
        addonName = addonName,
    }

    self.modules[name] = module

    return module
end

function UI:GetModule(name)
    return self.modules[name]
end