// vim: fileencoding=utf-8 tabstop=4 shiftwidth=4

// Copyright (c) 2010 , NetEase.com,Inc. All rights reserved.
//
// Author: Yang Bo (pop.atry@gmail.com)
//
// Use, modification and distribution are subject to the "New BSD License"
// as listed at <url: http://www.opensource.org/licenses/bsd-license.php >.

package protohx;
import static google.protobuf.compiler.Plugin.*;
import static com.google.protobuf.DescriptorProtos.*;
import com.google.protobuf.*;
import java.io.*;
import java.util.*;
import java.math.*;
public final class Proto2Haxe {
    private static final String[] ACTIONSCRIPT_KEYWORDS = {
      "as", "break", "case", "catch", "class", "const", "continue", "default",
      "delete", "do", "else", "extends", "false", "finally", "for",
      "function", "if", "implements", "import", "in", "instanceof",
      "interface", "internal", "is", "native", "new", "null", "package",
      "private", "protected", "public", "return", "super", "switch", "this",
      "throw", "to", "true", "try", "typeof", "use", "var", "void", "Void", "while",
      "with","callback","typedef","cast", "package"
   };
   private static final class Scope<Proto> {
      // 如果 proto instanceOf Scope ，则这个 Scope 是对另一 Scope 的引用
      public final String fullName;
      public final Scope<?> parent;
      public  Proto proto;
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
            result = (Scope<?>)result.proto;
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
             String s = proto instanceof EnumValueDescriptorProto ?parent.fullName:parent.fullName.toLowerCase();
             fullName = s + '.' + name;
         }
      }
      public <ChildProto> Scope<ChildProto> addChild(
            String name, ChildProto proto, boolean export) {
         assert(name != null);
         assert(!name.equals(""));
         Scope<ChildProto> child =
               new Scope<ChildProto>(this, proto, export, name);
         if(children.containsKey(child)) {
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
       final FieldDescriptorProto f = efdp.toBuilder().setName("ext_" + efdp.getName()).build();
       final DescriptorProto.Builder builder = scope.proto.toBuilder();
       builder.addField(f);
       scope.proto = builder.build();
   }
   private static void addEnumToScope(Scope<?> scope, EnumDescriptorProto edp,
         boolean export) {
      assert(edp.hasName());
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
      for (DescriptorProto nested: dp.getNestedTypeList()) {
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
   private static String getActionScript3WireType(
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
   private static String getActionScript3LogicType(Scope<?> scope,
         FieldDescriptorProto fdp) {
      if (fdp.getType() == FieldDescriptorProto.Type.TYPE_ENUM) {
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
      } else {
         return getActionScript3Type(scope, fdp);
      }
   }
   private static String getActionScript3Type(Scope<?> scope,
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
                    return "new "+typeScope.fullName.substring(
                            typeScope.fullName.lastIndexOf('.') + 1)+"()";
                }
                return typeScope.fullName;
            case TYPE_BYTES:
                return "defaultBytes()";
            default:
                throw new IllegalArgumentException();
        }
    }


    private static void appendQuotedString(StringBuilder sb, String value) {
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
   }
   private static void appendDefaultValue(StringBuilder sb, Scope<?> scope,
         FieldDescriptorProto fdp) {
      String value = fdp.getDefaultValue();
      switch (fdp.getType()) {
      case TYPE_DOUBLE:
      case TYPE_FLOAT:
         if (value.equals("nan")) {
            sb.append("Math.NaN");
         } else if (value.equals("inf")) {
            sb.append("Math.POSITIVE_INFINITY");
         } else if (value.equals("-inf")) {
            sb.append("Math.NEGATIVE_INFINITY");
         } else {
            sb.append(value);
         }
         break;
      case TYPE_UINT64:
      case TYPE_FIXED64:
         {
            long v = new BigInteger(value).longValue();
            sb.append("new UInt64(");
            sb.append(Long.toString(v & 0xFFFFFFFFL));
            sb.append(", ");
            sb.append(Long.toString((v >>> 32) & 0xFFFFFFFFL));
            sb.append(")");
         }
         break;
      case TYPE_INT64:
      case TYPE_SFIXED64:
      case TYPE_SINT64:
         {
            long v = Long.parseLong(value);
            sb.append("new Int64(");
            sb.append(Long.toString(v & 0xFFFFFFFFL));
            sb.append(", ");
            sb.append(Integer.toString((int)v >>> 32));
            sb.append(")");
         }
         break;
      case TYPE_INT32:
      case TYPE_FIXED32:
      case TYPE_SFIXED32:
      case TYPE_SINT32:
      case TYPE_UINT32:
      case TYPE_BOOL:
         sb.append(value);
         break;
      case TYPE_STRING:
         appendQuotedString(sb, value);
         break;
      case TYPE_ENUM:
          Scope<?> scope1 = scope.find(fdp.getTypeName());
          String fullName = scope1.
                  children.get(value).fullName;
          sb.append(fullName);
         break;
      case TYPE_BYTES:
         sb.append("stringToBytes(");
         sb.append("\"");
         sb.append(value);
         sb.append("\")");
         break;
      default:
         throw new IllegalArgumentException();
      }
   }
   private static void appendLowerCamelCase(StringBuilder sb, String s) {
      if (Arrays.binarySearch(ACTIONSCRIPT_KEYWORDS, s) >= 0) {
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
   }
   private static void appendUpperCamelCase(StringBuilder sb, String s) {
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
   }
   private static void writeMessage(Scope<DescriptorProto> scope,
         StringBuilder content, StringBuilder initializerContent) {
      content.append("import protohx.ProtocolTypes;\n");
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
      content.append(scope.proto.getName());
      content.append(" extends protohx.Message");
      content.append(" {\n");
      if (scope.proto.getExtensionRangeCount() > 0) {
//         content.append("\tpublic static/*const*/ inline var extensionReadFunctions:Array<PT_ReadFunction> = [];\n\n");
      }
      if (scope.proto.getExtensionCount() > 0) {
         initializerContent.append("import ");
         initializerContent.append(scope.fullName);
         initializerContent.append(";\n");
         initializerContent.append("void(");
         initializerContent.append(scope.fullName);
         initializerContent.append(");\n");
      }
       for (FieldDescriptorProto efdp : scope.proto.getExtensionList()) {
           content.append("//TODO Implement Extensions ");
//          if (efdp.getType() == FieldDescriptorProto.Type.TYPE_GROUP) {
//             System.err.println("Warning: Group is not supported.");
//             continue;
//          }
//          String extendee = scope.find(efdp.getExtendee()).fullName;
//          content.append("\t/**\n\t\t *  @private\n\t\t */\n");
//          content.append("\tpublic static /*const*/ inline var ");
//          content.append(efdp.getName().toUpperCase());
//          content.append(":");
//          appendFieldDescriptorClass(content, efdp);
//          content.append(" = ");
//          appendFieldDescriptor(content, scope, efdp);
//          content.append(";\n\n");
//          if (efdp.hasDefaultValue()) {
//             content.append("\t");
//             content.append(extendee);
//             content.append(".prototype[");
//             content.append(efdp.getName().toUpperCase());
//             content.append("] = ");
//             appendDefaultValue(content, scope, efdp);
//             content.append(";\n\n");
//          }
//          appendExtensionReadFunction(content, "\t", scope, efdp);
       }
       int valueTypeCount = 0;
      for (FieldDescriptorProto fdp : scope.proto.getFieldList()) {
         if (fdp.getType() == FieldDescriptorProto.Type.TYPE_GROUP) {
            System.err.println("Warning: Group is not supported.");
            continue;
         }
//         content.append("\t/**\n\t\t *  @private\n\t\t */\n");
//         content.append("\tpublic static/*const*/ inline var ");
//         content.append(fdp.getName().toUpperCase());
//         content.append(":");
//         appendFieldDescriptorClass(content, fdp);
//         content.append(" = ");
//         appendFieldDescriptor(content, scope, fdp);
//         content.append(";\n\n");
         assert(fdp.hasLabel());
         switch (fdp.getLabel()) {
         case LABEL_OPTIONAL:
            content.append("\tprivate var ");
            content.append(fdp.getName());
            content.append("__field:");
            content.append(getActionScript3Type(scope, fdp));
            content.append(";\n\n");

             content.append("\tpublic var ");
             appendLowerCamelCase(content, fdp.getName());
             //* haxe 3
             content.append("(get,set):");
             /*/
             content.append("(get_");
             appendLowerCamelCase(content, fdp.getName());
             content.append(",set_");
             appendLowerCamelCase(content, fdp.getName());
             content.append("):");*/
             content.append(getActionScript3Type(scope, fdp));
             content.append(";\n\n");


            if (isValueType(fdp.getType())) {
               final int valueTypeId = valueTypeCount++;
                int maxBits = 31;
                final int valueTypeField = valueTypeId / maxBits;
               final int valueTypeBit = valueTypeId % maxBits;
               if (valueTypeBit == 0) {
                  content.append("\tprivate var hasField__");
                  content.append(valueTypeField);
                  content.append(":PT_UInt = 0;\n\n");
               }

               content.append("\tpublic function clear");
               appendUpperCamelCase(content, fdp.getName());
               content.append("():Void {\n");
               content.append("\t\thasField__");
               content.append(valueTypeField);
               content.append(" &= 0x");
               content.append(Integer.toHexString(~(1 << valueTypeBit)));
               content.append(";\n");

               content.append("\t\t");
               content.append(fdp.getName());
               content.append("__field = " + getBlankObject(scope, fdp) +";\n");
               content.append("\t}\n\n");

               content.append("\tinline public function has");
               appendUpperCamelCase(content, fdp.getName());
               content.append("():PT_Bool {\n");
               content.append("\t\treturn (hasField__");
               content.append(valueTypeField);
               content.append(" & 0x");
               content.append(Integer.toHexString(1 << valueTypeBit));
               content.append(") != 0;\n");
               content.append("\t}\n\n");

               content.append("\tpublic function set_");
               appendLowerCamelCase(content, fdp.getName());
               content.append("(value:");
               content.append(getActionScript3Type(scope, fdp));
               content.append("):");
                content.append(getActionScript3Type(scope, fdp));
               content.append("{\n");
               content.append("\t\thasField__");
               content.append(valueTypeField);
               content.append(" |= 0x");
               content.append(Integer.toHexString(1 << valueTypeBit));
               content.append(";\n");
               content.append("\t\treturn ");
               content.append(fdp.getName());
               content.append("__field = value;\n");
               content.append("\t}\n\n");
            } else {
               content.append("\tpublic function clear");
               appendUpperCamelCase(content, fdp.getName());
               content.append("():Void {\n");
               content.append("\t\t");
               content.append(fdp.getName());
               content.append("__field = null;\n");
               content.append("\t}\n\n");

               content.append("\tinline public function has");
               appendUpperCamelCase(content, fdp.getName());
               content.append("():Bool {\n");
               content.append("\t\treturn ");
               content.append(fdp.getName());
               content.append("__field != null;\n");
               content.append("\t}\n\n");

               content.append("\tpublic function set_");
               appendLowerCamelCase(content, fdp.getName());
               content.append("(value:");
               content.append(getActionScript3Type(scope, fdp));
                content.append("):");
                content.append(getActionScript3Type(scope, fdp));
                content.append("{\n");
               content.append("\t\treturn ");
               content.append(fdp.getName());
               content.append("__field = value;\n");
               content.append("\t}\n\n");
            }

            content.append("\tpublic function get_");
            appendLowerCamelCase(content, fdp.getName());
            content.append("():");
            content.append(getActionScript3Type(scope, fdp));
            content.append(" {\n");
            if (fdp.hasDefaultValue()) {
               content.append("\t\tif(!has");
               appendUpperCamelCase(content, fdp.getName());
               content.append("()) {\n");
               content.append("\t\t\treturn ");
               appendDefaultValue(content, scope, fdp);
               content.append(";\n");
               content.append("\t\t}\n");
            }
            content.append("\t\treturn ");
            content.append(fdp.getName());
            content.append("__field;\n");
            content.append("\t}\n\n");
            break;
         case LABEL_REQUIRED:
            content.append("\tpublic var ");
            appendLowerCamelCase(content, fdp.getName());
            content.append(":");
            content.append(getActionScript3Type(scope, fdp));
            content.append(";\n\n");
            break;
         case LABEL_REPEATED:
            content.append("\tpublic var ");
            appendLowerCamelCase(content, fdp.getName());
            content.append(":Array<");
             content.append(getActionScript3Type(scope, fdp));
            content.append(">;\n\n");
            break;
         default:
            throw new IllegalArgumentException();
         }
      }

       content.append("\tpublic function new(){\n\t\t\tsuper();\n");
       for (FieldDescriptorProto fdp : scope.proto.getFieldList()) {
           if (fdp.getType() == FieldDescriptorProto.Type.TYPE_GROUP) {
               System.err.println("Warning: Group is not supported.");
               continue;
           }
           assert(fdp.hasLabel());
           switch (fdp.getLabel()) {
               case LABEL_REQUIRED:
                   if (fdp.hasDefaultValue()){
                       content.append("\t\tthis.");
                       appendLowerCamelCase(content, fdp.getName());
                       content.append(" = ");
                       appendDefaultValue(content, scope, fdp);
                       content.append(";\n");
                   } else {
                       content.append("\t\tthis.");
                       appendLowerCamelCase(content, fdp.getName());
                       content.append(" = ");
                       content.append(getBlankObject( scope, fdp));
                       content.append(";\n");
                   }
                   break;
               case LABEL_REPEATED:
                   content.append("\t\tthis.");
                   appendLowerCamelCase(content, fdp.getName());
                   content.append("= [];\n");
                   break;

           }
       }
       content.append("\t}\n");


      content.append("\t/**\n\t\t *  @private\n\t\t */\n\t\toverride public function writeToBuffer(output:PT_OutputStream):Void {\n");
      for (FieldDescriptorProto fdp : scope.proto.getFieldList()) {
         if (fdp.getType() == FieldDescriptorProto.Type.TYPE_GROUP) {
            System.err.println("Warning: Group is not supported.");
            continue;
         }
         switch (fdp.getLabel()) {
         case LABEL_OPTIONAL:
            content.append("\t\tif (");
            content.append("has");
            appendUpperCamelCase(content, fdp.getName());
            content.append("()) {\n");
            content.append("\t\t\tprotohx.WriteUtils.writeTag(output, protohx.WireType.");
            content.append(getActionScript3WireType(fdp.getType()));
            content.append(", ");
            content.append(Integer.toString(fdp.getNumber()));
            content.append(");\n");
            content.append("\t\t\tprotohx.WriteUtils.write__");
            content.append(fdp.getType().name());
            content.append("(output, ");
            content.append(fdp.getName());
            content.append("__field);\n");
            content.append("\t\t}\n");
            break;
         case LABEL_REQUIRED:
            content.append("\t\tprotohx.WriteUtils.writeTag(output, protohx.WireType.");
            content.append(getActionScript3WireType(fdp.getType()));
            content.append(", ");
            content.append(Integer.toString(fdp.getNumber()));
            content.append(");\n");
            content.append("\t\tprotohx.WriteUtils.write__");
            content.append(fdp.getType().name());
            content.append("(output, this.");
            appendLowerCamelCase(content, fdp.getName());
            content.append(");\n");
            break;
         case LABEL_REPEATED:
            if (fdp.hasOptions() && fdp.getOptions().getPacked()) {
               content.append("\t\tif (this.");
               appendLowerCamelCase(content, fdp.getName());
               content.append(" != null && this.");
               appendLowerCamelCase(content, fdp.getName());
               content.append(".length > 0) {\n");
               content.append("\t\t\tprotohx.WriteUtils.writeTag(output, protohx.WireType.LENGTH_DELIMITED, ");
               content.append(Integer.toString(fdp.getNumber()));
               content.append(");\n");
               content.append("\t\t\tprotohx.WriteUtils.writePackedRepeated(output, protohx.WriteUtils.write__");
               content.append(fdp.getType().name());
               content.append(", this.");
               appendLowerCamelCase(content, fdp.getName());
               content.append(");\n");
               content.append("\t\t}\n");
            } else {
               content.append("\t\tif (this.");
               appendLowerCamelCase(content, fdp.getName());
               content.append(" != null) for (");
               appendLowerCamelCase(content, fdp.getName());
               content.append("__index in 0...this.");
               appendLowerCamelCase(content, fdp.getName());
               content.append(".length) {\n");
               content.append("\t\t\tprotohx.WriteUtils.writeTag(output, protohx.WireType.");
               content.append(getActionScript3WireType(fdp.getType()));
               content.append(", ");
               content.append(Integer.toString(fdp.getNumber()));
               content.append(");\n");
               content.append("\t\t\tprotohx.WriteUtils.write__");
               content.append(fdp.getType().name());
               content.append("(output, this.");
               appendLowerCamelCase(content, fdp.getName());
               content.append("[");
               appendLowerCamelCase(content, fdp.getName());
               content.append("__index]);\n");
               content.append("\t\t}\n");
            }
            break;
         }
      }

      content.append("\t\tsuper.writeExtensionOrUnknownFields(output);\n");

      content.append("\t}\n\n");
      content.append("\t/**\n\t\t *  @private\n\t\t */\n");
      content.append("\toverride public function readFromSlice(input:PT_InputStream, bytesAfterSlice:PT_UInt):Void {\n");
      for (FieldDescriptorProto fdp : scope.proto.getFieldList()) {
         if (fdp.getType() == FieldDescriptorProto.Type.TYPE_GROUP) {
            System.err.println("Warning: Group is not supported.");
            continue;
         }
         switch (fdp.getLabel()) {
         case LABEL_OPTIONAL:
         case LABEL_REQUIRED:
            content.append("\t\tvar ");
            content.append(fdp.getName());
            content.append("__count:PT_UInt = 0;\n");
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
         content.append("\t\t\tcase ");
         content.append(Integer.toString(fdp.getNumber()));
         content.append(":\n");
         switch (fdp.getLabel()) {
         case LABEL_OPTIONAL:
         case LABEL_REQUIRED:
            content.append("\t\t\t\tif (");
            content.append(fdp.getName());
            content.append("__count != 0) {\n");
            content.append("\t\t\t\t\tthrow new PT_IOError('Bad data format: ");
            content.append(scope.proto.getName());
            content.append('.');
            appendLowerCamelCase(content, fdp.getName());
            content.append(" cannot be set twice.');\n");
            content.append("\t\t\t\t}\n");
            content.append("\t\t\t\t++");
            content.append(fdp.getName());
            content.append("__count;\n");
            if (fdp.getType() == FieldDescriptorProto.Type.TYPE_MESSAGE) {
               content.append("\t\t\t\tthis.");
               appendLowerCamelCase(content, fdp.getName());
               content.append(" = new ");
               content.append(getActionScript3Type(scope, fdp));
               content.append("();\n");
               content.append("\t\t\t\tprotohx.ReadUtils.read__TYPE_MESSAGE(input, this.");
               appendLowerCamelCase(content, fdp.getName());
               content.append(");\n");
            } else {
               content.append("\t\t\t\tthis.");
               appendLowerCamelCase(content, fdp.getName());
               content.append(" = protohx.ReadUtils.read__");
               content.append(fdp.getType().name());
               content.append("(input);\n");
            }
            break;
         case LABEL_REPEATED:
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
                  content.append("\t\t\t\t\tprotohx.ReadUtils.readPackedRepeated(input, protohx.ReadUtils.read__");
                  content.append(fdp.getType().name());
                  content.append(", this.");
                  appendLowerCamelCase(content, fdp.getName());
                  content.append(");\n");
                  content.append("\t\t\t\t\t/*break;//1*/\n");
                  content.append("\t\t\t\t}\n");
            }

            content.append("\t\t\t\tif(this.");
            appendLowerCamelCase(content, fdp.getName());
            content.append(" == null) this.");
            appendLowerCamelCase(content, fdp.getName());
             content.append(" = [];\n");

            if (fdp.getType() == FieldDescriptorProto.Type.TYPE_MESSAGE) {
               content.append("\t\t\t\tthis.");
               appendLowerCamelCase(content, fdp.getName());
               content.append(".push(cast ");
               content.append("protohx.ReadUtils.read__TYPE_MESSAGE(input, ");
               content.append("new ");
               content.append(getActionScript3Type(scope, fdp));
               content.append("()));\n");
            } else {
               content.append("\t\t\t\tthis.");
               appendLowerCamelCase(content, fdp.getName());
               content.append(".push(cast protohx.ReadUtils.read__");
               content.append(fdp.getType().name());
               content.append("(input));\n");
            }
            break;
         }
//         content.append("\t\t\t\t/*break;//2*/\n");
      }
      content.append("\t\t\tdefault:\n");
//      if (scope.proto.getExtensionRangeCount() > 0) {
//         content.append("\t\t\t\tsuper.readExtensionOrUnknown(extensionReadFunctions, input, tag);\n");
//      } else {
         content.append("\t\t\t\tsuper.readUnknown(input, tag);\n");
//      }
//      content.append("\t\t\t\t/*break;//3*/\n");
      content.append("\t\t\t}\n");
      content.append("\t\t}\n");
      content.append("\t}\n\n");
      content.append("}\n");
   }

    //    private static void appendFieldDescriptorClass(StringBuilder content,
//         FieldDescriptorProto fdp) {
//      switch (fdp.getLabel()) {
//      case LABEL_REQUIRED:
//      case LABEL_OPTIONAL:
//         break;
//      case LABEL_REPEATED:
//         content.append("Repeated");
//         break;
//      default:
//         throw new IllegalArgumentException();
//      }
//      content.append("FieldDescriptor__");
//      content.append(fdp.getType().name());
//   }
//   private static void appendFieldDescriptor(StringBuilder content,
//         Scope<?> scope,
//         FieldDescriptorProto fdp) {
//      content.append("new ");
//      appendFieldDescriptorClass(content, fdp);
//      content.append("(");
//      if (scope.parent == null) {
//         appendQuotedString(content, fdp.getName());
//      } else {
//         appendQuotedString(content, scope.fullName + '.' + fdp.getName());
//      }
//      content.append(", ");
//      if (fdp.hasExtendee()) {
//         if (scope.proto instanceof DescriptorProto) {
//            appendQuotedString(content, scope.fullName + '/' + fdp.getName().toUpperCase());
//         } else {
//            if (scope.parent == null) {
//               appendQuotedString(content, fdp.getName().toUpperCase());
//            } else {
//               appendQuotedString(content, scope.fullName + '.' + fdp.getName().toUpperCase());
//            }
//         }
//      } else {
//         StringBuilder fieldName = new StringBuilder();
//         appendLowerCamelCase(fieldName, fdp.getName());
//         appendQuotedString(content, fieldName.toString());
//      }
//      content.append(", (");
//      switch (fdp.getLabel()) {
//      case LABEL_REQUIRED:
//      case LABEL_OPTIONAL:
//         content.append(Integer.toString(fdp.getNumber()));
//         content.append(" << 3) | protohx.WireType.");
//         content.append(getActionScript3WireType(fdp.getType()));
//         break;
//      case LABEL_REPEATED:
//         if (fdp.hasOptions() && fdp.getOptions().getPacked()) {
//            content.append(Integer.toString(fdp.getNumber()));
//            content.append(" << 3) | protohx.WireType.LENGTH_DELIMITED");
//         } else {
//            content.append(Integer.toString(fdp.getNumber()));
//            content.append(" << 3) | protohx.WireType.");
//            content.append(getActionScript3WireType(fdp.getType()));
//         }
//         break;
//      }
//      switch (fdp.getType()) {
//      case TYPE_MESSAGE:
//         if (scope.proto instanceof DescriptorProto) {
//            content.append(", function():Class { return ");
//            content.append(getActionScript3LogicType(scope, fdp));
//            content.append("; }");
//         } else {
//            content.append(", ");
//            content.append(getActionScript3LogicType(scope, fdp));
//         }
//         break;
//      case TYPE_ENUM:
//         content.append(", ");
//         content.append(getActionScript3LogicType(scope, fdp));
//         break;
//      }
//      content.append(")");
//   }
//   private static void appendExtensionReadFunction(StringBuilder content,
//         String tabs,
//         Scope<?> scope,
//         FieldDescriptorProto fdp) {
//      String extendee = scope.find(fdp.getExtendee()).fullName;
//      switch (fdp.getLabel()) {
//      case LABEL_REQUIRED:
//      case LABEL_OPTIONAL:
//         content.append(tabs);
//         content.append(extendee);
//         content.append(".extensionReadFunctions[(");
//         content.append(Integer.toString(fdp.getNumber()));
//         content.append(" << 3) | protohx.WireType.");
//         content.append(getActionScript3WireType(fdp.getType()));
//         content.append("] = ");
//         content.append(fdp.getName().toUpperCase());
//         content.append(".read;\n\n");
//         break;
//      case LABEL_REPEATED:
//         content.append(tabs);
//         content.append(extendee);
//         content.append(".extensionReadFunctions[(");
//         content.append(Integer.toString(fdp.getNumber()));
//         content.append(" << 3) | protohx.WireType.");
//         content.append(getActionScript3WireType(fdp.getType()));
//         content.append("] = ");
//         content.append(fdp.getName().toUpperCase());
//         content.append(".readNonPacked;\n\n");
//         switch (fdp.getType()) {
//         case TYPE_MESSAGE:
//         case TYPE_BYTES:
//         case TYPE_STRING:
//            break;
//         default:
//            content.append(tabs);
//            content.append(extendee);
//            content.append(".extensionReadFunctions[(");
//            content.append(Integer.toString(fdp.getNumber()));
//            content.append(" << 3) | protohx.WireType.LENGTH_DELIMITED] = ");
//            content.append(fdp.getName().toUpperCase());
//            content.append(".readPacked;\n\n");
//            break;
//         }
//         break;
//      }
//   }
//   private static void writeExtension(Scope<FieldDescriptorProto> scope,
//         StringBuilder content, StringBuilder initializerContent) {
//      initializerContent.append("import ");
//      initializerContent.append(scope.fullName);
//      initializerContent.append(";\n");
//      initializerContent.append("void(");
//      initializerContent.append(scope.fullName);
//      initializerContent.append(");\n");
//      content.append("import com.netease.protobuf.*;\n");
//      content.append("import com.netease.protobuf.fieldDescriptors.*;\n");
//      String importType = getImportType(scope.parent, scope.proto);
//      if (importType != null) {
//         content.append("import ");
//         content.append(importType);
//         content.append(";\n");
//      }
//      String extendee = scope.parent.find(scope.proto.getExtendee()).fullName;
//      content.append("import ");
//      content.append(extendee);
//      content.append(";\n");
//      content.append("// @@protoc_insertion_point(imports)\n\n");
//
//      content.append("// @@protoc_insertion_point(constant_metadata)\n");
//      content.append("/**\n\t *  @private\n\t */\n");
//      content.append("public/*const*/ inline var ");
//      content.append(scope.proto.getName().toUpperCase());
//      content.append(":");
//      appendFieldDescriptorClass(content, scope.proto);
//      content.append(" = ");
//      appendFieldDescriptor(content, scope.parent, scope.proto);
//      content.append(";\n\n");
//      if (scope.proto.hasDefaultValue()) {
//         content.append("");
//         content.append(extendee);
//         content.append(".prototype[");
//         content.append(scope.proto.getName().toUpperCase());
//         content.append("] = ");
//         appendDefaultValue(content, scope.parent, scope.proto);
//         content.append(";\n\n");
//      }
//      appendExtensionReadFunction(content, "", scope.parent, scope.proto);
//   }

   private static void writeEnum(Scope<EnumDescriptorProto> scope,
         StringBuilder content) {
      content.append("import protohx.ProtocolTypes;\n");
      content.append("class ");
      content.append(scope.proto.getName());
      content.append(" {\n");
      for (EnumValueDescriptorProto evdp : scope.proto.getValueList()) {
         content.append("\tpublic static /*const*/ inline var ");
         content.append(evdp.getName());
         content.append(":PT_Int = ");
         content.append(evdp.getNumber());
         content.append(";\n");
      }
      content.append("}\n");
   }
   @SuppressWarnings("unchecked")
   private static void writeFile(Scope<?> scope, StringBuilder content,
         StringBuilder initializerContent) {
      content.append("package ");
      content.append(scope.parent.fullName.toLowerCase());
      content.append(";\n");
      if (scope.proto instanceof DescriptorProto) {
         writeMessage((Scope<DescriptorProto>)scope, content,
               initializerContent);
      } else if (scope.proto instanceof EnumDescriptorProto) {
         writeEnum((Scope<EnumDescriptorProto>)scope, content);
      } else if (scope.proto instanceof FieldDescriptorProto) {
         Scope<FieldDescriptorProto> fdpScope =
               (Scope<FieldDescriptorProto>)scope;
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
         CodeGeneratorResponse.Builder responseBuilder,
         StringBuilder initializerContent) {
      for (Map.Entry<String, Scope<?>> entry : root.children.entrySet()) {
         Scope<?> scope = entry.getValue();
         if (scope.export) {
            StringBuilder content = new StringBuilder();
            writeFile(scope, content, initializerContent);
            responseBuilder.addFile(
                CodeGeneratorResponse.File.newBuilder().
                    setName(scope.fullName.replace('.', '/') + ".hx").
                    setContent(content.toString()).
                build()
            );
         }
         writeFiles(scope, responseBuilder, initializerContent);
      }
   }
   private static void writeFiles(Scope<?> root,
         CodeGeneratorResponse.Builder responseBuilder) {
      StringBuilder initializerContent = new StringBuilder();
      initializerContent.append("{\n");
      writeFiles(root, responseBuilder, initializerContent);
      initializerContent.append("}\n");
//      responseBuilder.addFile(
//         CodeGeneratorResponse.File.newBuilder().
//            setName("initializer.as.inc").
//            setContent(initializerContent.toString()).
//         build()
//      );
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

