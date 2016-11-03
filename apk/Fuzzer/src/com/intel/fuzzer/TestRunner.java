/*
* Copyright (C) 2016 Intel Corporation
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*      http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/


package com.intel.fuzzer;

import java.io.ByteArrayOutputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.PrintStream;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;

public class TestRunner {
    public static String runTests(FileOutputStream fos, long seed){
        ByteArrayOutputStream os = new ByteArrayOutputStream();
        FuzzerUtils.out = new PrintStream(os);
        for (int i=-1; i<10000; i++){
            try {
                Class clazz = null;
                if (i!=-1)
                    clazz = Class.forName("com.intel.fuzzer.Test"+i);
                else clazz = Class.forName("com.intel.fuzzer.Test");
                Method method = clazz.getMethod("main", String[].class);
                final Object[] args = new Object[1];
                args[0] = new String[1];
                ((String[])args[0])[0] = seed+"";
                FuzzerUtils.out.println("Running "+clazz.getName());
                method.invoke(null, args);
            } catch (ClassNotFoundException e) {
                if (i>10) {
                    i = 10000;
                }
            } catch (NoSuchMethodException e) {
                e.printStackTrace();
            } catch (IllegalAccessException e) {
                e.printStackTrace();
            } catch (InvocationTargetException e) {
                e.printStackTrace();
            }
        }
        //Test.main(null);

        String out = os.toString();
        if (fos!=null){
            try {
                fos.write(out.getBytes());
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
        return out;
    }
    public static void main(String[] args){
        try {
            FileOutputStream fos = null;
            long seed = 0L;
            if (args.length>=1) {
                seed = Long.parseLong(args[0]);
            }
            if (args.length>=2) {
                fos = new FileOutputStream(args[1]);
            }
            System.out.print(runTests(fos, seed));
            if (fos != null) {
                fos.close();
            }
        } catch (FileNotFoundException e) {
            e.printStackTrace();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }
}
