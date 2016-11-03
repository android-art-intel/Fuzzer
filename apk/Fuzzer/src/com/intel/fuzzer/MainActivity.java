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

import android.app.Activity;
import android.content.Context;
import android.os.Bundle;
import android.util.Log;
import android.widget.TextView;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;

public class MainActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        Bundle extras = getIntent().getExtras();
        long seed = 0L;
        long minTime = 1000L;
        final long start = System.currentTimeMillis();
        boolean extras_flag = false;
        if (extras!=null){
            if (extras.containsKey("seed")){
                Log.i("FUZZER_SEED",extras.getString("seed"));
                seed = Long.parseLong(extras.getString("seed"));
                extras_flag = true;
            }
            if (extras.containsKey("time")){
                Log.i("FUZZER_TIME",extras.getString("time"));
                minTime = Long.parseLong(extras.getString("time"));
                extras_flag = true;
            }
            if (!extras_flag){
                Log.i("FUZZER_EXTRAS","No seed extra, but some other extras exist!");
            }
        } else {
            Log.i("FUZZER_EXTRAS","No extras!");
        }
        final long seedf = seed;
        final long min_time = minTime;
        Thread t = new Thread(new Runnable() {
            @Override
            public void run() {
                FileOutputStream fos = null;
                try {
                    String filename = "FuzzerOut.txt";
                    fos = openFileOutput(filename, Context.MODE_WORLD_READABLE);
                    Log.i("FUZZER_OUTFILE", getFilesDir().getAbsolutePath()+"/"+filename);
                } catch (FileNotFoundException e) {
                    //e.printStackTrace();
                    Log.i("FUZZER_EXCEPTION", e.getMessage()+"\n"+e.getStackTrace());
                }
                final String out = TestRunner.runTests(fos,seedf);
                try {
                    fos.close();
                } catch (IOException e) {
                    //e.printStackTrace();
                    Log.i("FUZZER_EXCEPTION", e.getMessage()+"\n"+e.getStackTrace());
                }
                runOnUiThread(new Runnable(){
                    @Override
                    public void run() {
                        TextView tv = (TextView)findViewById(R.id.MainTextView);
                        tv.setText(out);
                    }
                });
                long finish = System.currentTimeMillis();
                long left = (min_time-(finish-start));
                if (left>0){
                    Log.i("FUZZER", "Need to sleep for additional "+left+" ms");
                    try {
                        Thread.sleep(left);
                    } catch (InterruptedException e) {
                        //e.printStackTrace();
                        Log.i("FUZZER_EXCEPTION", e.getMessage()+"\n"+e.getStackTrace());
                    }
                }
                Log.i("FUZZER_FINISHED", "finished");
            }
        });
        t.start();
    }
}
