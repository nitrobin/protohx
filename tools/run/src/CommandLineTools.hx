package ;
import haxe.Json;
import haxe.Serializer;
import haxe.Unserializer;
import haxe.io.Path;
import haxe.rtti.Meta;
import sys.io.File;
import sys.FileSystem;
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
        //TODO optimize
        var config:Dynamic = readConfigSafe();
        var path = config.protocPath;
        return path != null ? path : DEFAULUT_PROTOC_PATH;
    }

	public function getProtohxBaseDir():String {
		return protohxBaseDir;
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
        if (task.haxeOut != null) { 
            Sys.println("task.haxeOut: " + task.haxeOut);			
			if (task.cleanOut){
                Sys.println("clean: " + task.haxeOut);			
			    PathHelper.removeDirectory(task.haxeOut);
			}
		    PathHelper.mkdirs(task.haxeOut);
            task.haxeOut = FileSystem.fullPath(task.haxeOut);
	    }
        if (task.javaOut != null) { 
			if (task.cleanOut){
                Sys.println("clean: " + task.javaOut);			
			    PathHelper.removeDirectory(task.javaOut);
			}
		    PathHelper.mkdirs(task.javaOut);
            task.javaOut = FileSystem.fullPath(task.javaOut);
	    }

		var oldCwd = Sys.getCwd();
		var newCwd = oldCwd;
        var args:Array<String> = [];
        if (task.haxeOut != null) {
			var pluginFileName = "plugin";
			if (PlatformHelper.isWindows()) {
				pluginFileName += ".bat";
			}
			var pluginDir = FileSystem.fullPath(context.getProtohxBaseDir() + "/tools/plugin/bin/");
            if (!PlatformHelper.isWindows()) {
				var pluginPath = PathHelper.norm(pluginDir + "/" + pluginFileName);
			    PlatformHelper.setExecutableBit(pluginPath); // TODO optimize 
			}              
            newCwd = pluginDir;
            args.push("--plugin=protoc-gen-haxe=" + pluginFileName);
            args.push("--haxe_out=" + PathHelper.norm(task.haxeOut));
        }
        if (task.javaOut != null) {
            args.push("--java_out=" + PathHelper.norm(task.javaOut));
        }
		args.push("--proto_path=" + PathHelper.norm(FileSystem.fullPath(task.protoPath)));
        for (pf in task.protoFiles){
            args.push(PathHelper.norm(FileSystem.fullPath(pf)));
        }

		Sys.setCwd(newCwd);
        var protocPath = context.getProtocPath();
        var code = PlatformHelper.command(protocPath, args);
		Sys.setCwd(oldCwd);
        Sys.println("----");
        if (code != 0) {
            Sys.println("TIP: Check config and proto-files.");
            Sys.println("     Check protoc and java in system path.");
            Sys.println("----");
            Sys.println("FAIL");
        } else {
            if (task.haxeOut != null) {Sys.println("Haxe sources generated in '" + PathHelper.norm(task.haxeOut) + "'");}
            if (task.javaOut != null) {Sys.println("Java sources generated in '" + PathHelper.norm(task.javaOut) + "'");}
           Sys.println("----");
           Sys.println("SUCCESS");
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
                    Sys.println("protocPath: " + context.getProtocPath());
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
                    Sys.println("protocPath: " + context.getProtocPath());
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