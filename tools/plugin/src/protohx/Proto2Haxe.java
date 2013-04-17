// vim: fileencoding=utf-8 tabstop=4 shiftwidth=4

// Copyright (c) 2010 , NetEase.com,Inc. All rights reserved.
//
// Author: Yang Bo (pop.atry@gmail.com)
//
// Use, modification and distribution are subject to the "New BSD License"
// as listed at <url: http://www.opensource.org/licenses/bsd-license.php >.

package protohx;

import com.google.protobuf.ExtensionRegistry;

import java.io.*;
import java.math.BigInteger;
import java.util.*;

import static com.google.protobuf.DescriptorProtos.*;
import static google.protobuf.compiler.Plugin.CodeGeneratorRequest;
import static google.protobuf.compiler.Plugin.CodeGeneratorResponse;

public final class Proto2Haxe {
    private static final Set<String> ACTIONSCRIPT_KEYWORDS = new HashSet<String>(Arrays.asList(
            "as", "break", "case", "catch", "class", "const", "continue", "default",
            "delete", "do", "else", "extends", "false", "finally", "for",
            "function", "if", "implements", "import", "in", "instanceof",
            "interface", "internal", "is", "native", "new", "null", "package",
            "private", "protected", "public", "return", "super", "switch", "this",
            "throw", "to", "true", "try", "typeof", "use", "var", "void", "Void", "while",
            "with", "callback", "typedef", "cast"
    ));

    private static final class Scope<Proto> {
        // 如果 proto instanceOf Scope ，则这个 Scope 是对另一 Scope 的引用
        public final String fullName;
        public final Scope<?> parent;
        public Proto proto;
        public final boolean export;
        public final HashMap<String, Scope<?>> children =
                new HashMap<String, Scope<?>>();

        private Scope<?> find(String[] pathElements, int i) {
            Scope<?> result = this;
            for (; i < pathElements.length; i++) {
                String name = pathElements[i];
                if (result.children.containsKey(name)) {
                    result = result.children.get(name);
                } else {
                    return null;
                }
            }
            while (result.proto instanceof Scope) {
                result = (Scope<?>) result.proto;
            }
            return result;
        }

        public boolean isRoot() {
            return parent == null;
        }

        private Scope<?> getRoot() {
            Scope<?> scope = this;
            while (!scope.isRoot()) {
                scope = scope.parent;
            }
            return scope;
        }

        public Scope<?> find(String path) {
            String[] pathElements = path.split("\\.");
            if (pathElements[0].equals("")) {
                return getRoot().find(pathElements, 1);
            } else {
                for (Scope<?> scope = this; scope != null; scope = scope.parent) {
                    Scope<?> result = scope.find(pathElements, 0);
                    if (result != null) {
                        return result;
                    }
                }
                return null;
            }
        }

        private Scope<?> findOrCreate(String[] pathElements, int i) {
            Scope<?> scope = this;
            for (; i < pathElements.length; i++) {
                String name = pathElements[i];
                if (scope.children.containsKey(name)) {
                    scope = scope.children.get(name);
                } else {
                    Scope<Object> child =
                            new Scope<Object>(scope, null, false, name);
                    scope.children.put(name, child);
                    scope = child;
                }
            }
            return scope;
        }

        public Scope<?> findOrCreate(String path) {
            String[] pathElements = path.split("\\.");
            if (pathElements[0].equals("")) {
                return getRoot().findOrCreate(pathElements, 1);
            } else {
                return findOrCreate(pathElements, 0);
            }
        }

        private Scope(Scope<?> parent, Proto proto, boolean export,
                      String name) {
            this.parent = parent;
            this.proto = proto;
            this.export = export;
            if (isRoot() || parent.isRoot()) {
                fullName = name;
            } else {
                String s = proto instanceof EnumValueDescriptorProto ? parent.fullName : parent.fullName.toLowerCase();
                fullName = s + '.' + name;
            }
        }

        public <ChildProto> Scope<ChildProto> addChild(
                String name, ChildProto proto, boolean export) {
            assert (name != null);
            assert (!name.equals(""));
            Scope<ChildProto> child =
                    new Scope<ChildProto>(this, proto, export, name);
            if (children.containsKey(child)) {
                throw new IllegalArgumentException();
            }
            children.put(name, child);
            return child;
        }

        public static Scope<Object> newRoot() {
            return new Scope<Object>(null, null, false, "");
        }
    }

    private static void addServiceToScope(Scope<?> scope,
                                          ServiceDescriptorProto sdp, boolean export) {
        scope.addChild(sdp.getName(), sdp, export);
    }

    private static void addExtensionToScope(Scope<?> scope_,
                                            FieldDescriptorProto efdp, boolean export) {
//      scope.addChild(efdp.getName().toUpperCase(), efdp, export);
        final Scope<DescriptorProto> scope = (Scope<DescriptorProto>) scope_.find(efdp.getExtendee());
        final FieldDescriptorProto f = efdp/*.toBuilder().setName("ext_" + efdp.getName()).build()*/;
        final DescriptorProto.Builder builder = scope.proto.toBuilder();
        builder.addField(f);
        scope.proto = builder.build();
    }

    private static void addEnumToScope(Scope<?> scope, EnumDescriptorProto edp,
                                       boolean export) {
        assert (edp.hasName());
        Scope<EnumDescriptorProto> enumScope =
                scope.addChild(edp.getName(), edp, export);
        for (EnumValueDescriptorProto evdp : edp.getValueList()) {
            Scope<EnumValueDescriptorProto> enumValueScope =
                    enumScope.addChild(evdp.getName(), evdp, false);
            scope.addChild(evdp.getName(), enumValueScope, false);
        }
    }

    private static void addMessageToScope(Scope<?> scope, DescriptorProto dp,
                                          boolean export) {
        Scope<DescriptorProto> messageScope =
                scope.addChild(dp.getName(), dp, export);
        for (EnumDescriptorProto edp : dp.getEnumTypeList()) {
            addEnumToScope(messageScope, edp, export);
        }
        for (DescriptorProto nested : dp.getNestedTypeList()) {
            addMessageToScope(messageScope, nested, export);
        }
    }

    private static Scope<Object> buildScopeTree(CodeGeneratorRequest request) {
        Scope<Object> root = Scope.newRoot();
        List<String> filesToGenerate = request.getFileToGenerateList();
        for (FileDescriptorProto fdp : request.getProtoFileList()) {
            Scope<?> packageScope = fdp.hasPackage() ?
                    root.findOrCreate(fdp.getPackage()) : root;
            boolean export = filesToGenerate.contains(fdp.getName());
            for (ServiceDescriptorProto sdp : fdp.getServiceList()) {
                addServiceToScope(packageScope, sdp, export);
            }
            for (EnumDescriptorProto edp : fdp.getEnumTypeList()) {
                addEnumToScope(packageScope, edp, export);
            }
            for (DescriptorProto dp : fdp.getMessageTypeList()) {
                addMessageToScope(packageScope, dp, export);
            }
            for (FieldDescriptorProto efdp : fdp.getExtensionList()) {
                addExtensionToScope(packageScope, efdp, export);
            }
        }
        return root;
    }

    private static String getImportType(Scope<?> scope,
                                        FieldDescriptorProto fdp) {
        switch (fdp.getType()) {
            case TYPE_ENUM:
            case TYPE_MESSAGE:
                Scope<?> typeScope = scope.find(fdp.getTypeName());
                if (typeScope == null) {
                    throw new IllegalArgumentException(
                            fdp.getTypeName() + " not found.");
                }
                return typeScope.fullName;
            case TYPE_BYTES:
                return null;
            default:
                return null;
        }
    }

    private static boolean isValueType(FieldDescriptorProto.Type type) {
        switch (type) {
            case TYPE_DOUBLE:
            case TYPE_FLOAT:
            case TYPE_INT32:
            case TYPE_FIXED32:
            case TYPE_BOOL:
            case TYPE_UINT32:
            case TYPE_SFIXED32:
            case TYPE_SINT32:
            case TYPE_ENUM:
            case TYPE_INT64:
            case TYPE_UINT64:
            case TYPE_FIXED64:
            case TYPE_SFIXED64:
            case TYPE_SINT64:
                return true;
            default:
                return false;
        }
    }

    static final int VARINT = 0;
    static final int FIXED_64_BIT = 1;
    static final int LENGTH_DELIMITED = 2;
    static final int FIXED_32_BIT = 5;

    private static int getWireType(
            FieldDescriptorProto.Type type) {
        switch (type) {
            case TYPE_DOUBLE:
            case TYPE_FIXED64:
            case TYPE_SFIXED64:
                return FIXED_64_BIT;
            case TYPE_FLOAT:
            case TYPE_FIXED32:
            case TYPE_SFIXED32:
                return FIXED_32_BIT;
            case TYPE_INT32:
            case TYPE_SINT32:
            case TYPE_UINT32:
            case TYPE_BOOL:
            case TYPE_INT64:
            case TYPE_UINT64:
            case TYPE_SINT64:
            case TYPE_ENUM:
                return VARINT;
            case TYPE_STRING:
            case TYPE_MESSAGE:
            case TYPE_BYTES:
                return LENGTH_DELIMITED;
            default:
                throw new IllegalArgumentException();
        }
    }

    private static String getHaxeWireType(
            FieldDescriptorProto.Type type) {
        switch (type) {
            case TYPE_DOUBLE:
            case TYPE_FIXED64:
            case TYPE_SFIXED64:
                return "FIXED_64_BIT";
            case TYPE_FLOAT:
            case TYPE_FIXED32:
            case TYPE_SFIXED32:
                return "FIXED_32_BIT";
            case TYPE_INT32:
            case TYPE_SINT32:
            case TYPE_UINT32:
            case TYPE_BOOL:
            case TYPE_INT64:
            case TYPE_UINT64:
            case TYPE_SINT64:
            case TYPE_ENUM:
                return "VARINT";
            case TYPE_STRING:
            case TYPE_MESSAGE:
            case TYPE_BYTES:
                return "LENGTH_DELIMITED";
            default:
                throw new IllegalArgumentException();
        }
    }

    private static String getHaxeType(Scope<?> scope,
                                      FieldDescriptorProto fdp) {
        switch (fdp.getType()) {
            case TYPE_DOUBLE:
                return "PT_Double";
            case TYPE_FLOAT:
                return "PT_Float";
            case TYPE_INT32:
            case TYPE_SFIXED32:
            case TYPE_SINT32:
            case TYPE_ENUM: //TODO use haxe enum
                return "PT_Int";
            case TYPE_UINT32:
            case TYPE_FIXED32:
                return "PT_UInt";
            case TYPE_BOOL:
                return "PT_Bool";
            case TYPE_INT64:
            case TYPE_SFIXED64:
            case TYPE_SINT64:
                return "PT_Int64";
            case TYPE_UINT64:
            case TYPE_FIXED64:
                return "PT_UInt64";
            case TYPE_STRING:
                return "PT_String";
            case TYPE_MESSAGE:
                Scope<?> typeScope = scope.find(fdp.getTypeName());
                if (typeScope == null) {
                    throw new IllegalArgumentException(
                            fdp.getTypeName() + " not found.");
                }
                if (typeScope == scope) {
                    // workaround for mxmlc's bug.
                    return typeScope.fullName.substring(
                            typeScope.fullName.lastIndexOf('.') + 1);
                }
                return typeScope.fullName;
            case TYPE_BYTES:
                return "PT_Bytes";
            default:
                throw new IllegalArgumentException();
        }
    }

    private static String getBlankObject(Scope<DescriptorProto> scope, FieldDescriptorProto fdp) {
        switch (fdp.getType()) {
            case TYPE_ENUM: //TODO use haxe enum
                return "0";
            case TYPE_DOUBLE:
            case TYPE_FLOAT:
            case TYPE_INT32:
            case TYPE_SFIXED32:
            case TYPE_SINT32:
            case TYPE_UINT32:
            case TYPE_FIXED32:
                return "0";
            case TYPE_BOOL:
                return "false";
            case TYPE_INT64:
            case TYPE_SFIXED64:
            case TYPE_SINT64:
                return "defaultInt64()";
            case TYPE_UINT64:
            case TYPE_FIXED64:
                return "defaultUInt64()";
            case TYPE_STRING:
                return "\"\"";
            case TYPE_MESSAGE:
                Scope<?> typeScope = scope.find(fdp.getTypeName());
                if (typeScope == null) {
                    throw new IllegalArgumentException(
                            fdp.getTypeName() + " not found.");
                }
                if (typeScope == scope) {
                    // workaround for mxmlc's bug.
                    return "new " + typeScope.fullName.substring(
                            typeScope.fullName.lastIndexOf('.') + 1) + "()";
                }
                return typeScope.fullName;
            case TYPE_BYTES:
                return "defaultBytes()";
            default:
                throw new IllegalArgumentException();
        }
    }


    private static String quotedString(String value) {
        StringBuilder sb = new StringBuilder();
        sb.append('\"');
        for (int i = 0; i < value.length(); i++) {
            char c = value.charAt(i);
            switch (c) {
                case '\"':
                case '\\':
                    sb.append('\\');
                    sb.append(c);
                    break;
                default:
                    if (c >= 128 || Character.isISOControl(c)) {
                        sb.append("\\u");
                        sb.append(String.format("%04X", new Integer(c)));
                    } else {
                        sb.append(c);
                    }
            }
        }
        sb.append('\"');
        return sb.toString();
    }

    private static String defaultValue(Scope<?> scope, FieldDescriptorProto fdp) {
        String value = fdp.getDefaultValue();
        switch (fdp.getType()) {
            case TYPE_DOUBLE:
            case TYPE_FLOAT:
                if (value.equals("nan")) {
                    return "Math.NaN";
                } else if (value.equals("inf")) {
                    return "Math.POSITIVE_INFINITY";
                } else if (value.equals("-inf")) {
                    return "Math.NEGATIVE_INFINITY";
                } else {
                    return value;
                }
            case TYPE_UINT64:
            case TYPE_FIXED64: {
                long v = new BigInteger(value).longValue();
                return "Protohx.newUInt64(" + Integer.toString((int) (v >>> 32)) + ", " + Integer.toString((int) (v & 0xFFFFFFFFL)) + ")";
            }
            case TYPE_INT64:
            case TYPE_SFIXED64:
            case TYPE_SINT64: {
                long v = new BigInteger(value).longValue();
                return "Protohx.newInt64(" + Integer.toString((int) (v >>> 32)) + ", " + Integer.toString((int) (v & 0xFFFFFFFFL)) + ")";
            }
            case TYPE_INT32:
            case TYPE_FIXED32:
            case TYPE_SFIXED32:
            case TYPE_SINT32:
            case TYPE_UINT32:
            case TYPE_BOOL:
                return value;
            case TYPE_STRING:
                return quotedString(value);
            case TYPE_ENUM:
                return scope.find(fdp.getTypeName())
                        .children.get(value).fullName;
            case TYPE_BYTES:
                return "stringToBytes(\"" + value + "\")";
            default:
                throw new IllegalArgumentException();
        }
    }

    private static String getLowerCamelCaseField(FieldDescriptorProto fdp) {
        return getLowerCamelCase(fdp.getName());
    }

    private static String getLowerCamelCase(String s) {
        StringBuilder sb = new StringBuilder();
        if (ACTIONSCRIPT_KEYWORDS.contains(s)) {
            sb.append("__");
        }
        sb.append(Character.toLowerCase(s.charAt(0)));
        boolean upper = false;
        for (int i = 1; i < s.length(); i++) {
            char c = s.charAt(i);
            if (upper) {
                if (Character.isLowerCase(c)) {
                    sb.append(Character.toUpperCase(c));
                    upper = false;
                    continue;
                } else {
                    sb.append('_');
                }
            }
            upper = c == '_';
            if (!upper) {
                sb.append(c);
            }
        }
        return sb.toString();
    }

    private static String getUpperCamelCaseField(FieldDescriptorProto fdp) {
        return getUpperCamelCase(fdp.getName());
    }

    private static String getUpperCamelCase(String s) {
        StringBuilder sb = new StringBuilder();
        sb.append(Character.toUpperCase(s.charAt(0)));
        boolean upper = false;
        for (int i = 1; i < s.length(); i++) {
            char c = s.charAt(i);
            if (upper) {
                if (Character.isLowerCase(c)) {
                    sb.append(Character.toUpperCase(c));
                    upper = false;
                    continue;
                } else {
                    sb.append('_');
                }
            }
            upper = c == '_';
            if (!upper) {
                sb.append(c);
            }
        }
        return sb.toString();
    }

    private static void writeMessage(Scope<DescriptorProto> scope, StringBuilder content) {
        content.append("import protohx.Protohx;\n");
        HashSet<String> importTypes = new HashSet<String>();
        for (FieldDescriptorProto efdp : scope.proto.getExtensionList()) {
            importTypes.add(scope.find(efdp.getExtendee()).fullName);
            if (efdp.getType().equals(FieldDescriptorProto.Type.TYPE_MESSAGE)) {
                importTypes.add(scope.find(efdp.getTypeName()).fullName);
            }
            String importType = getImportType(scope, efdp);
            if (importType != null) {
                importTypes.add(importType);
            }
        }
        for (FieldDescriptorProto fdp : scope.proto.getFieldList()) {
            String importType = getImportType(scope, fdp);
            if (importType != null) {
                importTypes.add(importType);
            }
        }
        for (String importType : importTypes) {
            content.append("import ");
            content.append(importType);
            content.append(";\n");
        }
        content.append("class ");
        final String className = scope.proto.getName();
        content.append(className);
        content.append(" extends protohx.Message");
        content.append(" {\n");

        int valueTypeCount = 0;
        for (FieldDescriptorProto fdp : scope.proto.getFieldList()) {
            if (fdp.getType() == FieldDescriptorProto.Type.TYPE_GROUP) {
                System.err.println("Warning: Group is not supported.");
                continue;
            }
            final String lowerCamelCaseField = getLowerCamelCaseField(fdp);
            final String upperCamelCaseField = getUpperCamelCaseField(fdp);
            final String haxeType = getHaxeType(scope, fdp);
            final boolean valueType = isValueType(fdp.getType());
            content.append("\n\t/** " + fdp.getLabel() + " " + fdp.getName() + " : " + fdp.getType() + " = " + fdp.getNumber() + " */\n");

            assert (fdp.hasLabel());
            switch (fdp.getLabel()) {
                case LABEL_OPTIONAL:
                    content.append(varDefinition(lowerCamelCaseField, haxeType, false));
                    content.append(varHelperSetter(lowerCamelCaseField, upperCamelCaseField, haxeType, false, className));

                    if (valueType) {
                        final int valueTypeId = valueTypeCount++;
                        final int maxBits = 31;
                        final int valueTypeField = valueTypeId / maxBits;
                        final int valueTypeBit = valueTypeId % maxBits;
                        if (valueTypeBit == 0) {
                            content.append("\tprivate var hasField__" + valueTypeField + ":PT_UInt = 0;\n\n");
                        }

                        content.append("\tpublic function clear" + upperCamelCaseField + "():Void {\n");
                        content.append("\t\thasField__" + valueTypeField + " &= 0x" + Integer.toHexString(~(1 << valueTypeBit)) + ";\n");
                        content.append("\t\tthis." + lowerCamelCaseField + " = " + getBlankObject(scope, fdp) + ";\n");
                        content.append("\t}\n\n");

                        content.append("\tinline public function has" + upperCamelCaseField + "():PT_Bool {\n");
                        content.append("\t\treturn (hasField__" + valueTypeField + " & 0x" + Integer.toHexString(1 << valueTypeBit) + ") != 0;\n");
                        content.append("\t}\n\n");

                        content.append("\tpublic function set_" + lowerCamelCaseField + "(value:" + haxeType + "):" + haxeType + "{\n");
                        content.append("\t\thasField__" + valueTypeField + " |= 0x" + Integer.toHexString(1 << valueTypeBit) + ";\n");
                        content.append("\t\treturn this." + lowerCamelCaseField + " = value;\n");
                        content.append("\t}\n\n");
                    } else {
                        content.append("\tpublic function clear" + upperCamelCaseField + "():Void {\n");
                        content.append("\t\tthis." + lowerCamelCaseField + " = null;\n");
                        content.append("\t}\n\n");

                        content.append("\tinline public function has" + upperCamelCaseField + "():Bool {\n");
                        content.append("\t\treturn this." + lowerCamelCaseField + " != null;\n");
                        content.append("\t}\n\n");

                        content.append("\tpublic function set_" + lowerCamelCaseField + "(value:" + haxeType + "):" + haxeType + "{\n");
                        content.append("\t\treturn this." + lowerCamelCaseField + " = value;\n");
                        content.append("\t}\n\n");
                    }

                    content.append("\tpublic function get_" + lowerCamelCaseField + "():" + haxeType + " {\n");
                    if (fdp.hasDefaultValue()) {
                        content.append("\t\tif(!has" + upperCamelCaseField + "()) {\n");
                        content.append("\t\t\treturn " + defaultValue(scope, fdp) + ";\n");
                        content.append("\t\t}\n");
                    }
                    content.append("\t\treturn this." + lowerCamelCaseField + ";\n");
                    content.append("\t}\n\n");
                    break;
                case LABEL_REQUIRED:
                    content.append(varDefinition(lowerCamelCaseField, haxeType, false));
                    content.append(varHelperSetter(lowerCamelCaseField, upperCamelCaseField, haxeType, false, className));

                    content.append("\tpublic function set_" + lowerCamelCaseField + "(value:" + haxeType + "):" + haxeType + "{\n");
                    content.append("\t\treturn this." + lowerCamelCaseField + " = value;\n");
                    content.append("\t}\n\n");

                    content.append("\tpublic function get_" + lowerCamelCaseField + "():" + haxeType + " {\n");
                    content.append("\t\treturn this." + lowerCamelCaseField + ";\n");
                    content.append("\t}\n\n");

                    break;
                case LABEL_REPEATED:
                    content.append(varDefinition(lowerCamelCaseField, haxeType, true));
                    content.append(varHelperSetter(lowerCamelCaseField, upperCamelCaseField, haxeType, true, className));

                    content.append("\tpublic function set_" + lowerCamelCaseField + "(value:Array<" + haxeType + ">):Array<" + haxeType + "> {\n");
                    content.append("\t\treturn this." + lowerCamelCaseField + " = value;\n");
                    content.append("\t}\n\n");

                    content.append("\tpublic function get_" + lowerCamelCaseField + "():Array<" + haxeType + "> {\n");
                    content.append("\t\treturn this." + lowerCamelCaseField + ";\n");
                    content.append("\t}\n\n");

                    content.append("\tpublic function add" + upperCamelCaseField + "(value:" + haxeType + "):Void {\n");
                    content.append("\t\tif(this." + lowerCamelCaseField + " == null) this." + lowerCamelCaseField + " = [value];\n");
                    content.append("\t\telse this." + lowerCamelCaseField + ".push(value);\n");
                    content.append("\t}\n\n");
                    break;
                default:
                    throw new IllegalArgumentException();
            }
        }

        content.append("\tpublic function new(){\n\t\tsuper();\n");
        for (FieldDescriptorProto fdp : scope.proto.getFieldList()) {
            if (fdp.getType() == FieldDescriptorProto.Type.TYPE_GROUP) {
                System.err.println("Warning: Group is not supported.");
                continue;
            }
            assert (fdp.hasLabel());
            final String lowerCamelCaseField = getLowerCamelCaseField(fdp);
            switch (fdp.getLabel()) {
                case LABEL_REQUIRED:
                    if (fdp.hasDefaultValue()) {
                        content.append("\t\tthis." + lowerCamelCaseField + " = " + defaultValue(scope, fdp) + ";\n");
                    } else {
                        content.append("\t\tthis." + lowerCamelCaseField + " = " + getBlankObject(scope, fdp) + ";\n");
                    }
                    break;
                case LABEL_REPEATED:
                    content.append("\t\tthis." + lowerCamelCaseField + " = [];\n");
                    break;

            }
        }
        content.append("\t}\n\n");


        content.append("\t/** @private */\n");
        content.append("\toverride public function writeToBuffer(output:PT_OutputStream):Void {\n");
        for (FieldDescriptorProto fdp : scope.proto.getFieldList()) {
            if (fdp.getType() == FieldDescriptorProto.Type.TYPE_GROUP) {
                System.err.println("Warning: Group is not supported.");
                continue;
            }
            final String lowerCamelCaseField = getLowerCamelCaseField(fdp);
            final String upperCamelCaseField = getUpperCamelCaseField(fdp);
            final String haxeWireType = getHaxeWireType(fdp.getType());
            final String fieldNumber = Integer.toString(fdp.getNumber());
            final String typeName = fdp.getType().name();
            switch (fdp.getLabel()) {
                case LABEL_OPTIONAL:
                    content.append("\t\tif (has" + upperCamelCaseField + "()) {\n");
                    content.append("\t\t\tprotohx.WriteUtils.writeTag(output, protohx.WireType." + haxeWireType + ", " + fieldNumber + ");\n");
                    content.append("\t\t\tprotohx.WriteUtils.write__" + typeName + "(output, this." + lowerCamelCaseField + ");\n");
                    content.append("\t\t}\n");
                    break;
                case LABEL_REQUIRED:
                    content.append("\t\tprotohx.WriteUtils.writeTag(output, protohx.WireType." + haxeWireType + ", " + fieldNumber);
                    content.append(");\n");
                    content.append("\t\tprotohx.WriteUtils.write__" + typeName + "(output, this." + lowerCamelCaseField + ");\n");
                    break;
                case LABEL_REPEATED:
                    if (fdp.hasOptions() && fdp.getOptions().getPacked()) {
                        content.append("\t\tif (this." + lowerCamelCaseField + " != null && this." + lowerCamelCaseField + ".length > 0) {\n");
                        content.append("\t\t\tprotohx.WriteUtils.writeTag(output, protohx.WireType.LENGTH_DELIMITED, " + fieldNumber + ");\n");
                        content.append("\t\t\tprotohx.WriteUtils.writePackedRepeated(output, protohx.WriteUtils.write__" + typeName + ", this." + lowerCamelCaseField + ");\n");
                        content.append("\t\t}\n");
                    } else {
                        content.append("\t\tif (this." + lowerCamelCaseField + " != null) {\n");
                        content.append("\t\t\tfor (value in this." + lowerCamelCaseField + ") {\n");
                        content.append("\t\t\t\tprotohx.WriteUtils.writeTag(output, protohx.WireType." + haxeWireType + ", " + fieldNumber + ");\n");
                        content.append("\t\t\t\tprotohx.WriteUtils.write__" + typeName + "(output, value);\n");
                        content.append("\t\t\t}\n");
                        content.append("\t\t}\n");
                    }
                    break;
            }
        }

        content.append("\t\tsuper.writeExtensionOrUnknownFields(output);\n");
        content.append("\t}\n\n");


        content.append("\toverride public function forEachFields(fn:String->Dynamic->Void):Void {\n");
        for (FieldDescriptorProto fdp : scope.proto.getFieldList()) {
            final String lowerCamelCaseField = getLowerCamelCaseField(fdp);
            final String upperCamelCaseField = getUpperCamelCaseField(fdp);
            switch (fdp.getLabel()) {
                case LABEL_OPTIONAL:
                    content.append("\t\tif (has" + upperCamelCaseField + "()) {\n");
                    content.append("\t\t\tfn(\"" + lowerCamelCaseField + "\", this." + lowerCamelCaseField + ");\n");
                    content.append("\t\t}\n");
                    break;
                case LABEL_REQUIRED:
                    content.append("\t\t\tfn(\"" + lowerCamelCaseField + "\", this." + lowerCamelCaseField + ");\n");
                    break;
                case LABEL_REPEATED:
                    content.append("\t\tif (this." + lowerCamelCaseField + " != null && this." + lowerCamelCaseField + ".length > 0) {\n");
                    content.append("\t\t\tfn(\"" + lowerCamelCaseField + "\", this." + lowerCamelCaseField + ");\n");
                    content.append("\t\t}\n");
                    break;
            }
        }
        content.append("\t}\n\n");

        content.append("\t/** @private */\n");
        content.append("\toverride public function readFromSlice(input:PT_InputStream, bytesAfterSlice:PT_UInt):Void {\n");
        for (FieldDescriptorProto fdp : scope.proto.getFieldList()) {
            if (fdp.getType() == FieldDescriptorProto.Type.TYPE_GROUP) {
                System.err.println("Warning: Group is not supported.");
                continue;
            }
            switch (fdp.getLabel()) {
                case LABEL_OPTIONAL:
                case LABEL_REQUIRED:
                    final String fieldCounter = fdp.getName() + "__count";
                    content.append("\t\tvar " + fieldCounter + ":PT_UInt = 0;\n");
                    break;
            }
        }
        content.append("\t\twhile (hasBytes(input, bytesAfterSlice)) {\n");
        content.append("\t\t\tvar tag:PT_UInt = protohx.ReadUtils.read__TYPE_UINT32(input);\n");
        content.append("\t\t\tswitch (tag >> 3) {\n");
        for (FieldDescriptorProto fdp : scope.proto.getFieldList()) {
            if (fdp.getType() == FieldDescriptorProto.Type.TYPE_GROUP) {
                System.err.println("Warning: Group is not supported.");
                continue;
            }
            final String lowerCamelCaseField = getLowerCamelCaseField(fdp);
            final String haxeType = getHaxeType(scope, fdp);
            final String haxeWireType = fdp.getType().name();
            final String fieldNumber = Integer.toString(fdp.getNumber());
            content.append("\t\t\tcase " + fieldNumber + ":\n");
            switch (fdp.getLabel()) {
                case LABEL_OPTIONAL:
                case LABEL_REQUIRED:
                    final String fieldCounter = fdp.getName() + "__count";
                    content.append("\t\t\t\tif (" + fieldCounter + " != 0) {\n");
                    content.append("\t\t\t\t\tthrow new PT_IOError('Bad data format: " + className + "." + lowerCamelCaseField + " cannot be set twice.');\n");
                    content.append("\t\t\t\t}\n");
                    content.append("\t\t\t\t++" + fieldCounter + ";\n");
                    if (fdp.getType() == FieldDescriptorProto.Type.TYPE_MESSAGE) {
                        content.append("\t\t\t\tthis." + lowerCamelCaseField + " = new " + haxeType + "();\n");
                        content.append("\t\t\t\tprotohx.ReadUtils.read__TYPE_MESSAGE(input, this." + lowerCamelCaseField + ");\n");
                    } else {
                        content.append("\t\t\t\tthis." + lowerCamelCaseField + " = protohx.ReadUtils.read__" + haxeWireType + "(input);\n");
                    }
                    break;
                case LABEL_REPEATED:
                    content.append("\t\t\t\tif(this." + lowerCamelCaseField + " == null) {\n");
                    content.append("\t\t\t\t\tthis." + lowerCamelCaseField + " = [];\n");
                    content.append("\t\t\t\t}\n");
                    switch (fdp.getType()) {
                        case TYPE_DOUBLE:
                        case TYPE_FLOAT:
                        case TYPE_BOOL:
                        case TYPE_INT32:
                        case TYPE_FIXED32:
                        case TYPE_UINT32:
                        case TYPE_SFIXED32:
                        case TYPE_SINT32:
                        case TYPE_INT64:
                        case TYPE_FIXED64:
                        case TYPE_UINT64:
                        case TYPE_SFIXED64:
                        case TYPE_SINT64:
                        case TYPE_ENUM:
                            content.append("\t\t\t\tif ((tag & 7) == protohx.WireType.LENGTH_DELIMITED) {\n");
                            content.append("\t\t\t\t\tprotohx.ReadUtils.readPackedRepeated(input, protohx.ReadUtils.read__" + haxeWireType + ", this." + lowerCamelCaseField + ");\n");
                            content.append("\t\t\t\t} else ");
                    }
                    content.append("\t\t\t\t{\n");
                    if (fdp.getType() == FieldDescriptorProto.Type.TYPE_MESSAGE) {
                        content.append("\t\t\t\t\tthis." + lowerCamelCaseField + ".push(protohx.ReadUtils.read__TYPE_MESSAGE(input, new " + haxeType + "()));\n");
                    } else {
                        content.append("\t\t\t\t\tthis." + lowerCamelCaseField + ".push(cast protohx.ReadUtils.read__" + haxeWireType + "(input));\n");
                    }
                    content.append("\t\t\t\t}\n");
                    break;
            }
        }
        content.append("\t\t\tdefault:\n");
        content.append("\t\t\t\tsuper.readUnknown(input, tag);\n");
        content.append("\t\t\t}\n");
        content.append("\t\t}\n");
        content.append("\t}\n\n");
        content.append("}\n");
    }

    private static String varDefinition(String lowerCamelCaseField, String haxeType, boolean repeated) {
        if (repeated) {
            haxeType = "Array<" + haxeType + ">";
        }
        return "\t#if haxe3\n" +
                "\t@:isVar public var " + lowerCamelCaseField + "(get, set):" + haxeType + ";\n" +
                "\t#else\n" +
                "\tpublic var " + lowerCamelCaseField + "(get_" + lowerCamelCaseField + ", set_" + lowerCamelCaseField + "):" + haxeType + ";\n" +
                "\t#end\n\n";
    }

    private static String varHelperSetter(String lowerCamelCaseField, String upperCamelCaseField, String haxeType, boolean repeated, String className) {
        if (repeated) {
            haxeType = "Array<" + haxeType + ">";
        }
        return "\tpublic inline function set" + upperCamelCaseField + "(value:" + haxeType + "):" + className + "{\n" +
                "\t\tthis." + lowerCamelCaseField + " = value;\n" +
                "\t\treturn this;\n" +
                "\t}\n\n";
    }

    private static void writeEnum(Scope<EnumDescriptorProto> scope,
                                  StringBuilder content) {
        final String name = scope.proto.getName();
        content.append("import protohx.Protohx;\n");
        content.append("class " + name + " {\n");
        for (EnumValueDescriptorProto evdp : scope.proto.getValueList()) {
            final String valueName = evdp.getName();
            final int valueNumber = evdp.getNumber();
            content.append("\tpublic static /*const*/ inline var " + valueName + ":PT_Int = " + valueNumber + ";\n");
        }
        content.append("}\n");
    }

    @SuppressWarnings("unchecked")
    private static void writeFile(Scope<?> scope, StringBuilder content) {
        final String packageName = scope.parent.fullName.toLowerCase();
        content.append("package " + packageName + ";\n");
        if (scope.proto instanceof DescriptorProto) {
            writeMessage((Scope<DescriptorProto>) scope, content);
        } else if (scope.proto instanceof EnumDescriptorProto) {
            writeEnum((Scope<EnumDescriptorProto>) scope, content);
        } else if (scope.proto instanceof FieldDescriptorProto) {
            Scope<FieldDescriptorProto> fdpScope =
                    (Scope<FieldDescriptorProto>) scope;
            if (fdpScope.proto.getType() ==
                    FieldDescriptorProto.Type.TYPE_GROUP) {
                System.err.println("Warning: Group is not supported.");
            } else {
                content.append("//TODO Implement Extensions");
//            writeExtension(fdpScope, content, initializerContent);
            }
        } else {
            throw new IllegalArgumentException();
        }
        content.append("\n");
    }

    @SuppressWarnings("unchecked")
    private static void writeFiles(Scope<?> root,
                                   CodeGeneratorResponse.Builder responseBuilder) {
        for (Map.Entry<String, Scope<?>> entry : root.children.entrySet()) {
            Scope<?> scope = entry.getValue();
            if (scope.export) {
                StringBuilder content = new StringBuilder();
                writeFile(scope, content);
                responseBuilder.addFile(
                        CodeGeneratorResponse.File.newBuilder().
                                setName(scope.fullName.replace('.', '/') + ".hx").
                                setContent(content.toString()).
                                build()
                );
            }
            writeFiles(scope, responseBuilder);
        }
    }

    public static void main(String[] args) throws IOException {
        ExtensionRegistry registry = ExtensionRegistry.newInstance();
        InputStream in = (args.length == 0 ? System.in : new FileInputStream(args[0]));
        CodeGeneratorRequest request = CodeGeneratorRequest.
                parseFrom(in, registry);
        CodeGeneratorResponse response;
        try {
            Scope<Object> root = buildScopeTree(request);
            CodeGeneratorResponse.Builder responseBuilder =
                    CodeGeneratorResponse.newBuilder();
            writeFiles(root, responseBuilder);
            response = responseBuilder.build();
        } catch (Exception e) {
            // 出错，报告给 protoc ，然后退出
            StringWriter sw = new StringWriter();
            PrintWriter pw = new PrintWriter(sw);
            e.printStackTrace(pw);
            pw.flush();
            CodeGeneratorResponse.newBuilder().setError(sw.toString()).
                    build().writeTo(System.out);
            System.out.flush();
            return;
        }
        response.writeTo(System.out);
        System.out.flush();
    }
}

