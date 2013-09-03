class Waiter

  def initialize(project_info, ef_list)  #{{{2
    @ef_list      = ef_list
    @project_info = project_info
  end

  def print  #{{{2
    @ef_list[0].work_order.each do |order|
      puts "NEW ORDER"
      for key in order.keys
        puts "work_order[#{key.inspect}] = #{order[key].inspect}" #unless key == :section_data_points
#      if key == :section_data_points
#        puts "work_order[#{key.inspect}] = "
#        order[key].each do |item|
#          puts "    -- Data Point --------------------------------------------------------------------"
#          for k2 in item.keys
#            puts "    #{k2.inspect} = #{item[k2].inspect}"
#          end
#        end
#      end
      end
      puts "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    end
  end

  def to_html5  #{{{2
    puts "<!DOCTYPE html>"
    puts "<html>"
    puts "  <head>"
    puts "    <meta charset=\"utf-8\" />"
    puts "    <title>  SRDR Project Profiler  </title>"
    puts ""
    puts "    <link rel=\"stylesheet\" href=\"css/main.css\" type=\"text/css\" />"
    puts "    <!--[if IE]>"
    puts "    <script src=\"http://html5shiv.googlecode.com/svn/trunk/html5.js\"></script><![endif]-->"
    puts "    <!--[if lte IE 7]>"
    puts "    <script src=\"js/IE8.js\" type=\"text/javascript\"></script><![endif]-->"
    puts "    <!--[if lt IE 7]>"
    puts "    <link rel=\"stylesheet\" type=\"text/css\" media=\"all\" href=\"css/ie6.css\"/><![endif]-->"
    puts ""
    puts "  </head>"
    puts ""
    puts ""
    puts "  <body id=\"index\" class=\"home\">"
    puts "    <h1> Welcome to the SRDR Project Profiler </h1>"
    puts "    <h2> Project Title: #{@project_info[:title]} </h2>"
    @ef_list.each do |ef|
      puts "  <h3>Extraction Form: #{ef.extraction_form_title}</h3>"
      puts "    <table>"
      puts "      <tr>"
      puts "        <th>Section</th>"
      puts "        <th>Question</th>"
      puts "        <th>Type</th>"
      puts "        <th>Instructions</th>"
      puts "      </tr>"
      ef.work_order.each do |wo|
        puts "        <tr>"
        puts "          <td>#{wo[:section]}</td>"
        if wo[:section] == "QualityDimension"
          puts "          <td>#{wo["title"]}</td>"
        else
          puts "          <td>#{wo["question"]}</td>"
        end
        puts "          <td>#{wo["field_type"]}</td>"
        puts "          <td>#{wo["instruction"]}</td>"
        puts "        </tr>"
      end
      puts "    </table>"
    end
    puts "  </body>"
    puts "</html>"
  end

  def to_csv  #{{{2
  end
end
