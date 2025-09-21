package MR_Demo.demo;

import MR_Demo.demo.Mapper.MapClass;
import MR_Demo.demo.Reducer.ReducerClass;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.lib.input.TextInputFormat;
import org.apache.hadoop.mapreduce.lib.output.TextOutputFormat;


@SpringBootApplication
public class DemoApplication implements CommandLineRunner {

	public static void main(String[] args) {
		SpringApplication.run(DemoApplication.class, args);
	}


	@Override
	public void run(String... args) throws Exception {

		if(args.length != 2) {
			System.err.println("Insufficient arguments");
			System.exit(-1);
		}

		String inputPath = args[0];
		String outputPath = args[1];

		System.out.println("Running MapReduce job with:");
		System.out.println("Input: " + inputPath);
		System.out.println("Output: " + outputPath);

		Configuration conf = new Configuration();
//		conf.set("fs.default.name", "hdfs://localhost:50000");
		conf.set("mapred.job.tracker", "hdfs://localhost:50000");

//		conf.set("DrugName", args[3]);
		Job job = new Job(conf, "Sales Data");
		job.setJarByClass(DemoApplication.class);

		job.setMapperClass(MapClass.class);
		job.setReducerClass(ReducerClass.class);

		job.setMapOutputKeyClass(Text.class);
		job.setMapOutputValueClass(IntWritable.class);

		job.setOutputKeyClass(Text.class);
		job.setOutputValueClass(IntWritable.class);

		job.setMapperClass(MapClass.class);
		job.setReducerClass(ReducerClass.class);

		job.setInputFormatClass(TextInputFormat.class);	//default -- inputkey
		// keytype(longwritable) : valuetype(text)
		job.setOutputFormatClass(TextOutputFormat.class);

		job.setNumReduceTasks(1);	//no of reducer we need
		// Input/Output paths (local or HDFS)
		FileInputFormat.addInputPath(job, new Path(args[0]));	//input for hdfs
		FileOutputFormat.setOutputPath(job, new Path(args[1]));	//output of hdfs

		boolean success = job.waitForCompletion(true);	//to see log info of mapreduce
		System.out.println("Job finished with status: " + (success ? "SUCCESS" : "FAILURE"));
	}
}
