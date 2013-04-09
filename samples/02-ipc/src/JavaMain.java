import calc.Calc;

import java.io.*;

public class JavaMain {

    public static void main(String[] args) {
        try {
            InputStream in = (args.length == 0 ? System.in : new FileInputStream(args[0]));
            DataInputStream dis = new DataInputStream(in);
            DataOutputStream dos = new DataOutputStream(System.out);

            final int len = dis.readInt();
            final byte[] frame = new byte[len];
            dis.read(frame);
            final Calc.InputMessage inputMessage = Calc.InputMessage.parseFrom(frame);
            final Calc.OutputMessage outputMessage = process(inputMessage);
            final int size = outputMessage.getSerializedSize();
            dos.writeInt(size);
            outputMessage.writeTo(dos);
            dos.flush();
            System.out.flush();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private static Calc.OutputMessage process(Calc.InputMessage inputMessage) {
        try {
            if ((inputMessage.getOpCodesCount() + 1) != inputMessage.getValuesCount()) {
                throw new IllegalArgumentException();
            }
            int curOpIdx = inputMessage.getOpCodesCount() - 1;
            Calc.ValueMessage.Builder acc = inputMessage.getValues(inputMessage.getValuesCount() - 1).toBuilder();
            for (; curOpIdx >= 0; curOpIdx--) {
                Calc.ValueMessage.Builder topValue = inputMessage.getValues(curOpIdx).toBuilder();
                final Calc.OpCode opCode = inputMessage.getOpCodes(curOpIdx);
                evaluate(opCode, topValue, acc);
            }
            Calc.OutputMessage.Builder builder = Calc.OutputMessage.newBuilder();
            builder.setSuccess(true);
            builder.setValue(acc);

//            builder.setMsg("ok");

            builder.setMsg("ok: " +
                    (acc.hasFi64() ? acc.getFi64() : "null") + ":" +
                    (acc.hasSfi64() ? acc.getSfi64() : "null") + ":" +
                    (acc.hasUi64() ? acc.getUi64() : "null") + ":" +
                    (acc.hasSi64() ? acc.getSi64() : "null") + ":" +
                    (acc.hasI64() ? acc.getI64() : "null"));

            return builder.build();
        } catch (Throwable e) {
            Calc.OutputMessage.Builder builder = Calc.OutputMessage.newBuilder();
            builder.setSuccess(false);
            builder.setMsg("error: " + e);
            return builder.build();
        }
    }

    private static void evaluate(Calc.OpCode opCode, Calc.ValueMessage.Builder topValue, Calc.ValueMessage.Builder acc) {
        if (topValue.hasI32()) {
            final int a = topValue.getI32();
            final int b = acc.getI32();
            final int r = doInt32(opCode, a, b);
            acc.setI32(r);
        }
        if (topValue.hasFi32()) {
            final int a = topValue.getFi32();
            final int b = acc.getFi32();
            final int r = doInt32(opCode, a, b);
            acc.setFi32(r);
        }
        if (topValue.hasUi32()) {
            final int a = topValue.getUi32();
            final int b = acc.getUi32();
            final int r = doInt32(opCode, a, b);
            acc.setUi32(r);
        }
        if (topValue.hasSi32()) {
            final int a = topValue.getSi32();
            final int b = acc.getSi32();
            final int r = doInt32(opCode, a, b);
            acc.setSi32(r);
        }
        if (topValue.hasSfi32()) {
            final int a = topValue.getSfi32();
            final int b = acc.getSfi32();
            final int r = doInt32(opCode, a, b);
            acc.setSfi32(r);
        }
        if (topValue.hasFi64()) {
            final long a = topValue.getFi64();
            final long b = acc.getFi64();
            final long r = doInt32(opCode, a, b);
            acc.setFi64(r);
        }
        if (topValue.hasSfi64()) {
            final long a = topValue.getSfi64();
            final long b = acc.getSfi64();
            final long r = doInt32(opCode, a, b);
            acc.setSfi64(r);
        }
        if (topValue.hasI64()) {
            final long a = topValue.getI64();
            final long b = acc.getI64();
            final long r = doInt32(opCode, a, b);
            acc.setI64(r);
        }
        if (topValue.hasSi64()) {
            final long a = topValue.getSi64();
            final long b = acc.getSi64();
            final long r = doInt32(opCode, a, b);
            acc.setSi64(r);
        }
        if (topValue.hasUi64()) {
            final long a = topValue.getUi64();
            final long b = acc.getUi64();
            final long r = doInt32(opCode, a, b);
            acc.setUi64(r);
        }
        if (topValue.hasF()) {
            final float a = topValue.getF();
            final float b = acc.getF();
            final float r;
            if (opCode == Calc.OpCode.ADD) {
                r = (a + b);
            } else if (opCode == Calc.OpCode.SUB) {
                r = (a - b);
            } else if (opCode == Calc.OpCode.MUL) {
                r = (a * b);
            } else if (opCode == Calc.OpCode.DIV) {
                r = (a / b);
            } else {
                r = 0;
            }
            acc.setF(r);
        }
        if (topValue.hasD()) {
            final double a = topValue.getD();
            final double b = acc.getD();
            final double r;
            if (opCode == Calc.OpCode.ADD) {
                r = (a + b);
            } else if (opCode == Calc.OpCode.SUB) {
                r = (a - b);
            } else if (opCode == Calc.OpCode.MUL) {
                r = (a * b);
            } else if (opCode == Calc.OpCode.DIV) {
                r = (a / b);
            } else {
                r = 0;
            }
            acc.setD(r);
        }
    }

    private static long doInt32(Calc.OpCode opCode, long a, long b) {
        final long r;
        if (opCode == Calc.OpCode.ADD) {
            r = (a + b);
        } else if (opCode == Calc.OpCode.SUB) {
            r = (a - b);
        } else if (opCode == Calc.OpCode.MUL) {
            r = (a * b);
        } else if (opCode == Calc.OpCode.DIV) {
            r = (a / b);
        } else {
            r = 0;
        }
        return r;
    }

    private static int doInt32(Calc.OpCode opCode, int a, int b) {
        int r;
        if (opCode == Calc.OpCode.ADD) {
            r = (a + b);
        } else if (opCode == Calc.OpCode.SUB) {
            r = (a - b);
        } else if (opCode == Calc.OpCode.MUL) {
            r = (a * b);
        } else if (opCode == Calc.OpCode.DIV) {
            r = (a / b);
        } else {
            r = 0;
        }
        return r;
    }
}
