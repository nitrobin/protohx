package ;
import haxe.Json;
import haxe.Serializer;
import haxe.Unserializer;
import haxe.io.Path;
import haxe.rtti.Meta;
import sys.io.File;
import neko.Lib;
import sys.io.Process;
import sys.FileSystem;
import Helpers;

class Context {
    private var protohxBaseDir:String;
    public static inline var DEFAULUT_PROTOC_PATH = "protoc";

    public function new(protohxBaseDir) {
        this.protohxBaseDir = protohxBaseDir;
    }

    public function getDefaultConfigFileName():String {
        return "protohx.json";
    }

    public function saveConfig(config:Dynamic):Void {
        var jsonData = Json.stringify(config);
        File.saveContent(protohxBaseDir + "/config.json", jsonData);
    }

    public function readConfigSafe():Dynamic {
        try {
            var fileContent = File.getContent(protohxBaseDir + "/config.json");
            return Json.parse(fileContent);
        } catch (e:Dynamic) {
            return {};
        }
    }

    public function getProtocPath():String {
        var config:Dynamic = readConfigSafe();
        var path = config.protocPath;
        return path != null ? path : DEFAULUT_PROTOC_PATH;
    }

    public function getProtocPluginPath():String {
        var string = new Path(protohxBaseDir + "/tools/plugin/bin/plugin").toString();
        if (PlatformHelper.getHostPlatform() == Platform.WINDOWS) {
            string += ".bat";
        }
        return string;
    }
}


class TaskDef {
    public var protoFiles:Array<String>;
    public var protoPath:String;
    public var haxeOut:String;
    public var javaOut:String;
    public var cleanOut:Bool;

    public function new():Void {
    }

    public static function fromJson(taskJson:Dynamic):TaskDef {
        var result = new TaskDef();
        result.protoPath = taskJson.protoPath;
        result.haxeOut = taskJson.haxeOut;
        result.javaOut = taskJson.javaOut;
        result.cleanOut = (taskJson.cleanOut == true);
        result.protoFiles = taskJson.protoFiles;
        return result;
    }
}

class Error {
    public var msg:String;

    public function new(msg:String = "") {
        this.msg = msg;
    }
}

class CommandLineTools {

    public static function saveDefaultConfig(fileName:String):Void {
        var task = new TaskDef();
        task.protoPath = ".";
        task.haxeOut = "src-gen";
        task.javaOut = null;
        task.cleanOut = true;
        task.protoFiles = ["protocol.proto"];
        var jsonData = Json.stringify(task);
        File.saveContent(fileName, jsonData);
    }

    public static function parseConfig(fileName:String):TaskDef {
        var fileContent = File.getContent(fileName);
        var taskJson:Dynamic = Json.parse(fileContent);
        var result = TaskDef.fromJson(taskJson);

        if (result.protoPath == null) {
            result.protoPath = ".";
        }
        if (result.protoFiles == null || result.protoFiles.length == 0) {
            throw new Error("Required field 'protoFiles' is empty.");
        }
        if (result.haxeOut == null && result.javaOut == null) {
            throw new Error("Required fields 'haxeOut', 'javaOut' are empty.");
        }
        return result;
    }

    public static function executeTask(task:TaskDef, context:Context):Void {
        var protocPath = context.getProtocPath();
        var args:Array<String> = [
        "--proto_path=" + task.protoPath
        ];
        if (task.haxeOut != null) {
            args.push("--plugin=protoc-gen-haxe=" + context.getProtocPluginPath());
            args.push("--haxe_out=" + task.haxeOut);
        }
        if (task.javaOut != null) {
            args.push("--java_out=" + task.javaOut);
        }
        args = args.concat(task.protoFiles);
        if (task.cleanOut) {
            if (task.haxeOut != null) {PathHelper.removeDirectory(task.haxeOut);}
            if (task.javaOut != null) {PathHelper.removeDirectory(task.javaOut);}
        }
        if (task.haxeOut != null) {
            PathHelper.mkdirs(task.haxeOut);
        }
        if (task.javaOut != null) {
            PathHelper.mkdirs(task.javaOut);
        }
        var code = Sys.command(protocPath, args);
        if (code != 0) {
            Sys.println("Check config and proto-files.");
            Sys.println("TIP: Require protoc and java in system.");
        } else {
            if (task.haxeOut != null) {Sys.println('Haxe sources generated in ${task.haxeOut}');}
            if (task.javaOut != null) {Sys.println('Java sources generated in ${task.javaOut}');}
        }
    }

    public static function printHelp():Void {
        Sys.println("For generate sources:");
        Sys.println("\thaxelib run protohx generate [protohx.json]");
        Sys.println("For creating deafult config:");
        Sys.println("\thaxelib run protohx config [protohx.json]");
        Sys.println("For setup protoc location:");
        Sys.println("\thaxelib run protohx setup-protoc [protocPath]");
        Sys.println("DEPENDENCIES: Require protoc and java in your system.");
    }

    public static function main():Void {
        try {
            var context:Context = new Context(Sys.getCwd());
            var args = Sys.args();

            var last:String = (new Path(args[args.length - 1])).dir;
            if (FileSystem.exists(last) && FileSystem.isDirectory(last)) {
                Sys.setCwd(last);
            }
            args = args.slice(0, args.length - 1);
//            trace(args);

            if (args.length > 0) {
                var cmd = args[0];
                if (cmd == "generate" && args.length >= 1) {
                    Sys.println('protocPath: [${context.getProtocPath()}]');
                    var fileName = (args.length > 1 ? args[1] : context.getDefaultConfigFileName());
                    var config:TaskDef = parseConfig(fileName);
                    if (config.haxeOut != null || config.javaOut != null) {
                        executeTask(config, context);
                    }
                } else if (cmd == "setup-protoc" && args.length >= 1) {
                    var config = context.readConfigSafe();
                    if (args.length == 1) {
                        config.protocPath = null;
                    } else {
                        config.protocPath = args[1];
                    }
                    context.saveConfig(config);
                    Sys.println('protocPath: [${context.getProtocPath()}]');
                } else if (cmd == "config" && args.length >= 1) {
                    var fileName = (args.length > 1 ? args[1] : context.getDefaultConfigFileName());
                    saveDefaultConfig(fileName);
                } else {
                    printHelp();
                }
            } else {
                printHelp();
            }
        } catch (e:Error) {
            Sys.println("ERROR: ");
            Sys.println(e.msg);
        }

    }
}