local UI = KamiUI

UI.commands = UI.commands or {}

function UI:RegisterCommand(command, subcommand, callback, help)
    assert(type(command) == "string", "Command must be a string")
    assert(type(subcommand) == "string", "Subcommand must be a string")
    assert(type(callback) == "function", "Callback must be a function")

    self.commands[command] = self.commands[command] or {}

    self.commands[command][subcommand] = {
        callback = callback,
        help = help,
    }
end

function UI:ShowCommandHelp()
    self:Print("Available commands:")

    for command, subcommands in pairs(self.commands) do
        for subcommand, data in pairs(subcommands) do
            local text = "  /kami " .. command .. " " .. subcommand

            if data.help then
                text = text .. " - " .. data.help
            end

            self:Print(text)
        end
    end
end

function UI:HandleCommand(message)
    local args = {}

    for value in string.gmatch(message, "%S+") do
        table.insert(args, value)
    end

    local command = args[1]
    local subcommand = args[2]

    if not command or command == "help" then
        self:ShowCommandHelp()
        return
    end

    local commands = self.commands[command]

    if not commands then
        self:Print("Unknown command: " .. command)
        self:ShowCommandHelp()
        return
    end

    local entry = commands[subcommand]

    if not entry then
        self:Print("Unknown command: " .. command .. " " .. tostring(subcommand))
        self:ShowCommandHelp()
        return
    end

    entry.callback(select(3, unpack(args)))
end

SLASH_KAMIUI1 = "/kami"

SlashCmdList["KAMIUI"] = function(message)
    UI:HandleCommand(message)
end
