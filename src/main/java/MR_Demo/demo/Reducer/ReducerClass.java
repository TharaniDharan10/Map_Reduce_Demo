package MR_Demo.demo.Reducer;


import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Reducer;

import java.io.IOException;

public class ReducerClass extends Reducer<Text, IntWritable, Text, IntWritable> {


    //reducer has 4 methods : map, setup, cleanup, run
    //for the below code, the input is output of map. An example of input that i used as input is in format
    //input - amazon [2000, 1000, 3000]
    @Override
    protected void reduce(Text key, Iterable<IntWritable> values, Context context)
            throws IOException, InterruptedException {
        int sum = 0;
        for (IntWritable val : values) {
            sum += val.get();
        }
        context.write(key, new IntWritable(sum));
    }
}