package;
import haxe.Json;
import haxe.Serializer;
import haxe.Unserializer;
import haxe.io.Path;
import haxe.rtti.Meta;
import sys.io.File;
import sys.io.Process;
import sys.FileSystem;

class Helpers {
    public function new() {
    }
}


enum Platform {
    WINDOWS;
    LINUX;
    MAC;
}

class PathHelper {
    public static function norm(path:String):String {
        path = StringTools.replace(path, "\\", "/");
        path = StringTools.replace(path, "//", "/");
        if(PlatformHelper.isWindows()){
            path = StringTools.replace(path, "/", "\\");
        }
        return path;
    }

    public static function mkdirs(directory:String):Void {
        directory = StringTools.replace(directory, "\\", "/");
        var total = "";
        if (directory.substr(0, 1) == "/") {
            total = "/";
        }
        var parts = directory.split("/");
        var oldPath = "";
        if (parts.length > 0 && parts[0].indexOf(":") > -1) {
            oldPath = Sys.getCwd();
            Sys.setCwd(parts[0] + "\\");
            parts.shift();
        }
        for (part in parts) {
            if (part != "." && part != "") {
                if (total != "") {
                    total += "/";
                }
                total += part;
                if (!FileSystem.exists(total)) {
                    FileSystem.createDirectory(total);
                }
            }
        }
        if (oldPath != "") {
            Sys.setCwd(oldPath);
        }
    }

    public static function removeDirectory(directory:String):Void {
        if (FileSystem.exists(directory)) {
            for (file in FileSystem.readDirectory(directory)) {
                var path = directory + "/" + file;
                if (FileSystem.isDirectory(path)) {
                    removeDirectory(path);
                } else {
                    FileSystem.deleteFile(path);
                }
            }
            FileSystem.deleteDirectory(directory);
        }
    }
}

class PlatformHelper {
    private static var _hostPlatform:Platform;
// from http://code.google.com/p/nekonme/source/browse/tools/helpers/PlatformHelper.hx

    public static function isWindows():Bool {
        return getHostPlatform() == Platform.WINDOWS;
    }

    public static function getHostPlatform():Platform {
        if (_hostPlatform == null) {
            if (new EReg ("window", "i").match(Sys.systemName())) {
                _hostPlatform = Platform.WINDOWS;
            } else if (new EReg ("linux", "i").match(Sys.systemName())) {
                _hostPlatform = Platform.LINUX;
            } else if (new EReg ("mac", "i").match(Sys.systemName())) {
                _hostPlatform = Platform.MAC;
            }
        }
        return _hostPlatform;
    }

    public static function command( cmd : String, ?args : Array<String> ) : Int {
        Sys.println("---- PlatformHelper.command: ");
        Sys.println("  Sys.cwd: " + Sys.getCwd());
        Sys.println("  Sys.command: '" + cmd + "' '" + args.join("' '") + "'");
        return Sys.command(cmd, args);
    }

    public static function setExecutableBit(executable:String):Void {
        var platform = PlatformHelper.getHostPlatform();
        if (platform == Platform.LINUX || platform == Platform.MAC) {
            PlatformHelper.command("chmod", ["a+x", PathHelper.norm(executable)]);
        }
    }
}

