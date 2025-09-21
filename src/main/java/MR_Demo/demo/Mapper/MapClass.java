package MR_Demo.demo.Mapper;

import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Mapper;

import java.io.IOException;
import java.util.StringTokenizer;

public class MapClass extends Mapper<LongWritable, Text, Text, IntWritable> {

    //map has 4 methods : map, setup, cleanup, run

    //for the below code, an example of record that i used as input is in format
    //input - 1, amazon, mobile, 2000 .     Similarly there are multiple records
    @Override
    protected void map(LongWritable key, Text value, Context context)
            throws IOException, InterruptedException {
        String line = value.toString();
        String[] elements = line.split(",");
        Text keyWord = new Text(elements[1]);   //amazon
        int i = Integer.parseInt(elements[3]);  //2000
        IntWritable it = new IntWritable(i);
        context.write(keyWord, it);
    }
}
