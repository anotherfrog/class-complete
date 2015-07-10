module.exports =
    activate: ->
        # atom.workspaceView.command "class-complete:complete", => @complete()
        atom.commands.add "atom-workspace",
            "class-complete:complete": => @complete()

    complete: ->
        buffer = ""
        editor = atom.workspace.getActivePaneItem()
        cursor = editor.cursors[0];
        text = cursor.getCurrentBufferLine().trim()
        split = text.split ":"
        className = split[0]

        parameters = []
        if split[1]
            for param in split[1].split ","
                parameters.push param.trim() if param.trim()
        console.log split

        cursor.moveToEndOfLine()
        editor.selectToBeginningOfLine()

        buffer += "#{className} = (function() {\n"
        buffer += "\tfunction " + className + "("

        if parameters
            for param in [0..parameters.length - 1]
                if param == parameters.length - 1
                    buffer += parameters[parameters.length - 1] if parameters[parameters.length - 1]
                else
                    buffer += parameters[param] + ", " if parameters[param]

        buffer += ") {\n"
        if split.length > 2
            buffer += "\t\t#{split[2]}.apply(this, arguments);\n"

        buffer += "\t}\n"

        if split.length > 2
            buffer += "\n"
            buffer += "\t#{className}.prototype = Object.create(#{split[2]}.prototype);\n"
            buffer += "\t#{className}.prototype.constructor = #{className};\n"

        buffer += "\n"
        buffer += "\treturn #{className};"
        buffer += "\n}());"

        editor.insertText buffer
