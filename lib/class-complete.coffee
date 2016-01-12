
module.exports =

    activate: ->
        atom.commands.add "atom-workspace",
            "class-complete:complete": => @complete()

    complete: ->
        buffer = ""
        editor = atom.workspace.getActivePaneItem()
        cursor = editor.cursors[0]
        text = editor.getSelections()[0].getText()

        @tabString = "\t";
        tabLength = atom.config.get("editor.tabLength")
        if atom.config.get("editor.tabType") == "soft" or atom.config.get("editor.tabType") == "auto"
            @tabString = ""
            i = 0
            while i < 4
                i++
                @tabString += " "


        # Parse classdef to find out what needs to be generated
        classdef = module.exports.parseClassdef(text)

        if classdef.type == "class"

            # Start the class
            buffer += "#{classdef.fullname} = (function() {\n"

            # Indent and generate all methods needed
            buffer += module.exports.indent(module.exports.generateMethod(classdef.name, null, classdef.parameters, "constructor", {
                "before": "#{classdef.extends}.apply(this, arguments);" if classdef.extends
            }), 1)

            # If classdef extends another class, add appropriate code
            if classdef.extends
                buffer += "\n"
                buffer += "#{@tabString}#{classdef.name}.prototype = Object.create(#{classdef.extends}.prototype);\n"
                buffer += "#{@tabString}#{classdef.name}.prototype.constructor = #{classdef.name};\n"

            if classdef.methods.length > 0
                for method in [0..classdef.methods.length - 1]
                    if method >= 0
                        buffer += "\n"

                    method = classdef.methods[method]
                    buffer += module.exports.indent(module.exports.generateMethod(classdef.name, method.name, method.parameters, method.type), 1)

            buffer += "\n"
            buffer += "#{@tabString}return #{classdef.name};"
            buffer += "\n}());"

        else if classdef.type == "require"
                buffer += "var #{classdef.varName} = require(\"#{classdef.path}\");"
                buffer += "\n"

        editor.insertText buffer

    parseClassdef: (string) ->
        # <class_name>:<arguments>,...;<methods>,...:<extend>

        def = {
            fullname: null
            name: null,
            parameters: [],
            methods: [],
            extends: null,
            type: "class",
            varName : null,
            path: null
        }

        fullname = string.split(":")[0]

        def.fullname = fullname

        if (fullname.toLowerCase() == "r")
            varName = string.split(":")[1]
            path = string.split(":")[2]
            def.type = "require"
            def.varName = varName
            def.path = ((path != null) ? path : varName);
            if typeof path != "undefined" && path.length > 0
                def.path = path
            else
                def.path = varName

            return def

        string = string.replace(/\s/g, "")
        parts = string.split(":")

        if parts.length > 0
            def.name = parts[0]
            if parts.length > 1
                parameth = parts[1].split(";")
                parameters = parameth[0]
                methods = parameth[1]

                if parameters
                    def.parameters = module.exports.parseParameters(parameters)

                if methods

                    methods2 = methods.split("/")
                    for method in methods2
                        meth = {
                            name: null,
                            parameters: []
                            type: "method"
                        }

                        if method[0] == "@"
                            meth.type = "static"
                            method = method.substr(1, method.length - 1)

                        methsplit = method.split("+")
                        meth.name = methsplit[0] if methsplit.length > 0

                        meth.parameters = module.exports.parseParameters(methsplit[1]) if methsplit.length > 1

                        def.methods.push(meth) if meth.name

            if parts.length > 2
                def.extends = parts[2]

        return def

    parseParameters: (string) ->
        params = []

        string = string.replace(/\s/g, "").split(",")

        for part in string
            param = {
                name: null
                type: null
                instance: null
                member: false
                modes: []
            }

            parts = part.split("~")
            if parts.length > 1
                param.modes = parts[1].split("")
                part = parts[0]

            if part[0] == "@"
                param.member = true
                part = part.substr(1, part.length - 1)

            if part.split("!").length > 1
                split = part.split("!")

                param.name = split[0]
                param.type = split[1]
            else if part.split("^").length > 1
                split = part.split("^")

                param.name = split[0]
                param.instance = split[1]
            else
                param.name = part

            params.push(param)

        return params

    generateMethod: (className, method, parameters, type = "member", body = {}) ->
        if type == "static"
            buffer = "#{className}.#{method} = function("
        else if type == "method"
            buffer = "#{className}.prototype.#{method} = function("
        else if type == "constructor"
            buffer = "function #{className}("

        if parameters.length > 0
            for param in [0..parameters.length - 1]
                if param == parameters.length - 1
                    buffer += parameters[parameters.length - 1].name + ") {\n"
                else
                    buffer += parameters[param].name + ", "
        else
            buffer += ") {\n"

        buffer += "#{module.exports.indent(body.before, 1)}" if body.before

        checks = false
        members = false

        if parameters.length > 0
            buffer += "\n" if body.before
            for param in [0..parameters.length - 1]
                param = parameters[param]

                if param.member
                    members = true

                if param.type
                    checks = true
                    buffer += "#{@tabString}if (typeof #{param.name} !== \"#{param.type}\") throw new Error(\"Parameter '#{param.name}' expects to be type '#{param.type}'\");\n"
                if param.instance
                    checks = true
                    buffer += "#{@tabString}if (!(#{param.name} instanceof #{param.instance})) throw new Error(\"Parameter '#{param.name}' expects to be instance of '#{param.instance}'\");\n"


        if parameters.length > 0 && members
            buffer += "\n" if checks
            for param in [0..parameters.length - 1]
                param = parameters[param]
                if param.member
                    buffer += "#{@tabString}this.#{param.name} = #{param.name};\n"

        if body.after
            buffer += "\n" if checks || members
            buffer += "#{module.exports.indent(body.after, 1)}"

        buffer += "}"

        return buffer

    indent: (text, indent) ->
        buffer = ""
        lines = text.split(/\n|\r\n/)

        prefix = ""
        prefix += "#{@tabString}" for i in [0..indent - 1]

        for line in lines
            buffer += prefix + line + "\n"

        return buffer
