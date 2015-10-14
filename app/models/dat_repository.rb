class DatRepository

  attr_accessor :dir, :pool

  def initialize(dir: nil, pool: nil)
    raise ArgumentError, "You must provide either a dir or pool id" unless dir || pool
    @dir = dir ? dir : self.class.dir_from_pool_id(pool)
    FileUtils.mkdir_p @dir
  end

  def self.dir_from_pool_id(pool)
    pool_id = pool.instance_of?(Pool) ? pool.to_param : pool.to_s
    File.join dat_root, pool_id
  end

  def self.dat_root
    File.join Rails.root.to_s, 'dat'
  end

  def init
    %x(dat init --path=#{dir} --no-prompt)
  end

  def import(file: nil, data: nil, dataset: , key: nil)
    raise ArgumentError, "You must provide either a file or (string) data" unless data || file
    command =  "dat import"
    if data
      command = "#{data} | dat import -"
    else
      command = "dat import #{file}"
    end

    command << " -d #{dataset}"
    command << " -k #{key}" if key

    Dir.chdir(dir) { %x[#{command}] }
  end

  def identifier
    if pool.instance_of?(Pool)
      pool.to_param
    else
      File.basename(dir)
    end
  end

  # def diff(ref1, ref2=nil)
  #
  # end

end
