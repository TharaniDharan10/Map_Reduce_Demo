package MR_Demo.demo;

import MR_Demo.demo.Mapper.MapClass;
import MR_Demo.demo.Reducer.ReducerClass;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import org.apache.hadoop.mapreduce.lib.input.TextInputFormat;
import org.apache.hadoop.mapreduce.lib.output.TextOutputFormat;

public class DemoApplication {
	public static void main(String[] args) throws Exception {
		if (args.length != 2) {
			System.err.println("Usage: DemoApplication <input path> <output path>");
			System.exit(-1);
		}

		String inputPath = args[0];
		String outputPath = args[1];

		Configuration conf = new Configuration();
		Job job = Job.getInstance(conf, "Sales Data Analysis");

		job.setJarByClass(DemoApplication.class);
		job.setMapperClass(MapClass.class);
		job.setReducerClass(ReducerClass.class);

		job.setMapOutputKeyClass(Text.class);
		job.setMapOutputValueClass(IntWritable.class);
		job.setOutputKeyClass(Text.class);
		job.setOutputValueClass(IntWritable.class);

		job.setInputFormatClass(TextInputFormat.class);
		job.setOutputFormatClass(TextOutputFormat.class);
		job.setNumReduceTasks(1);

		FileInputFormat.addInputPath(job, new Path(inputPath));
		FileOutputFormat.setOutputPath(job, new Path(outputPath));

		boolean success = job.waitForCompletion(true);
		System.out.println("Job finished with status: " + (success ? "SUCCESS" : "FAILURE"));
	}
}
