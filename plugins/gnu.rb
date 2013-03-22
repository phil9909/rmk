
class CppArchive
  attr_accessor :objects, :includes
  def initialize()
    @objects = []
    @includes = []
  end
  def to_a()
    return @objects
  end
  def to_s()
    return @objects.to_s
  end
  def inspect()
    return @objects.inspect
  end
  def mtime()
    mtime = Time.at(0)
    @objects.each do | o |
      m = File.mtime(o)
      mtime = m if m > mtime
    end
    mtime
  end
end


module Gnu

  include BuildTools
  
  TARGET = "i486-linux"

  def cc(files,depends, options = {}) 
    result = CppArchive.new
    includes = [] 
    depends.each do | d |
      includes.concat(d.includes) if d.is_a?(CppArchive)
    end
    files.each do | cpp |
      result.objects << build_cache([cpp]) do | depends |
        basename, suffix  = File.basename(cpp).split(".")
        target_dir = File.join(build_dir,TARGET)
        ofile = File.join(target_dir,basename + ".o")
        dfile = File.join(target_dir,basename + ".d")
        FileUtils.mkdir_p(target_dir)
        system("gcc -x c++ -o #{ofile} #{includes.join(" ")} -MD -c #{cpp}")
        content = File.read(dfile)
        File.delete(dfile)
        content.gsub!(/\b[A-Z]:\//i,"/")
        content.gsub!(/^[^:]*:/,"")
        content.gsub!(/\\$/,"")
        content = content.split()
        content.shift()
        depends.concat(content)
        ofile
      end
    end
    result.includes.concat(files.map{ | x | "-I" + File.dirname(x)}.uniq)
    result.includes.concat(includes)
    [ result ]
  end
  
  def ar(name,objects, options = {}) 
  end
  
  def ld(name,depends, options = {}) 
    build_cache(depends) do
      target_dir = File.join(build_dir,TARGET)
      ofile = File.join(target_dir,name)
      objects = []
      depends.each { | d | objects.concat(d.to_a) }
      system("g++ #{objects.join(" ")} -o #{ofile} ")
      ofile
    end
  end
end
