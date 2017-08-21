# https://www.youtube.com/watch?v=XPlXNUXmcgE
# jose valim lambda days talk

# poem.txt
# "roses are red/n
# violets are blue/n"

# we tend to program solutions as eager, lazy, concurrent and distributed

#----------------------------
# EAGER (Enum)
#----------------------------
File.read!("poem.txt")
|> String.split("\n")
|> Enum.flat_map(& String.split/1)
|> Enum.reduce( %{}, fn word, map ->
  Map.update(map, word, 1, & &1 +1)
end)

#----------------------------
# LAZY (Stream)
#----------------------------
File.stream!("poem.txt", :line) # stream is lazy way to bring data in
|> Stream.flat_map(& String.split/1) # stream brings data line by line
|> Enum.reduce(%{}, fn word, map ->
  Map.update(map, word, 1, & &1 + 1)
end)
# Because this loads the data line by line, the entire file does not
# need to be loaded into memory, only each line as used

#----------------------------
# CONCURRENT (Flow)
#----------------------------
File.stream!("poem.txt", :line) # returns a recipe for how to read a file
|> Flow.from_enumerable() # converts the stream to a concrete recipe
|> Flow.flat_map(&String.split/1) # breaks each line into a process
|> Flow.partition() # maps each process stage to a 'sorting' stage
|> Flow.reduce(fn -> %{} end, fn word, map ->
  Map.update(map, word, 1, & &1 + 1)
end) # computes the maps concurrently, collects data into maps
|> Enum.into(%{}) # collects state into a map

# By going concurrent we give up locality and ordering
# With Flow you can work with bounded and infinite data
# While Enum is good for small collections, Flow requires large sets because
# there is a significant overhead in setting up the processes

# how are Flows implemented?
# GenStage - generic stage, exchanges data between stages
# breaks into producers, consumers and producer-consumers

# Flow.partition() allows to route data to proper stage

defmodule Producer do
  use GenStage

  def init(counter) do
    {:producer, counter}
  end

  def handle_demand(demand, counter) when demand > 0 do
    events = Enum.to_list(counter..counter+demand-1)
    {:noreply, events, counter + demand}
  end
end

defmodule Consumer do
  use GenStage
  def init(:ok) do
    {:consumer, :the_state_does_not_matter}
  end

  def handle_events(events, _from, state) do
    Process.sleep(1000)
    IO.inspect(events)
    {:noreply, [], state}
  end
end

{:ok, counter} =
  GenStage.start_link(Producer, 0)

{:ok, printer} =
  GenStage.start_link(Consumer, :ok)

GenStage.sync_subscribe(printer, to: counter)

# Why Flow? Flow provided map and reduce operations
# partitions, flow merge and flow join
# Configurable batch size
# Data windowing with triggers and watermarks

#----------------------------
# DISTRIBUTED
#----------------------------
# Flow API has feature parity with frameworks like Apache Spark
# BUT there's no distribution guarantees
# In some cases, single core is faster - must test first!
