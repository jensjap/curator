require "rubyXL"

require "./lib/environment.rb"
require "./lib/trollop.rb"
require "./lib/crawler.rb"
require "./lib/waiter.rb"

#workbook = RubyXL::Parser.parse("data/sample.xls")
#p workbook.worksheets[0]

## Minimal arg parser  {{{1
## http://trollop.rubyforge.org/
opts = Trollop::options do
  opt :project_id, "Project ID", :type => :integer
end

## This validates that required parameters have been passed to trollop  {{{1
def validate_arg_list(opts)
  Trollop::die :project_id, "You must supply a project id" unless opts[:project_id_given]
end

## Notifies the user of a critical error and quits the program  {{{1
## String -> Exit
def critical(err)
  puts err
  exit
end

## Builds a dictionary with project information for consumption later  {{{1
## (Project ID) -> (Dictionary of Project Information)
def get_project_info(project_id)
  begin
    project = Project.find(project_id)
  rescue ActiveRecord::RecordNotFound => err
    critical err
  else
    project_info = Hash.new
    project_info[:project_id] = project_id
    project_info[:title] = project.title
    project_info[:description] = project.description
    project_info[:notes] = project.notes
    project_info[:funding_source] = project.funding_source
    project_info[:creator_id] = project.creator_id
    begin
      creator = User.find(project.creator_id)
    rescue ActiveRecord::RecordNotFound => err
      puts "WARNING: #{err}"
      puts "WARNING: project_info:creator field left blank"
      project_info[:creator] = ""
    else
      project_info[:creator] = "#{creator.lname}, #{creator.fname}"
    end
    project_info[:is_public] = project.is_public
    project_info[:created_at] = project.created_at
    project_info[:updated_at] = project.updated_at
    project_info[:contributors] = project.contributors
    project_info[:methodology] = project.methodology
  end

  return project_info
end

## Puts together a list of extraction forms associated with the given project ID  {{{1
## Integer -> (listof ExtractionForm)
def get_extraction_forms(project_id)
  loef = Array.new
  extraction_forms = ExtractionForm.find_all_by_project_id(project_id)
  extraction_forms.each do |ef|
    loef.push(ef.id)
  end
  return loef
end



if __FILE__ == $0  # {{{1
  ## Validate trollop arguments passed
  validate_arg_list(opts)
  #puts "INFO: Validated runtime arguments"

  ## Constants
  PROJECT_ID = opts[:project_id]

  ## Variable decleration
  ef_list = Array.new

  ## Load rails environment so we have access to ActiveRecord
  #puts "INFO: Loading rails environment now.."
  load_rails_environment
  #puts "INFO: Finished loading rails environment"

  ## Gather project information
  #puts "INFO: Gathering information for project with ID: #{PROJECT_ID}"
  project_info = get_project_info(PROJECT_ID)
  #puts "INFO: Successfully gathered information on project ID: #{PROJECT_ID}"

  ## Put together a list of extraction forms associated with this project
  ef_id_list = get_extraction_forms(PROJECT_ID)
  if ef_id_list.empty?
    puts "No extraction forms found for this project. Terminating now."
    exit
  end

  ## For each extraction form in ef_list instantiate a Crawler object
  ef_id_list.each do |ef_id|
    c = Crawler.new(PROJECT_ID, ef_id)
    ef_list.push(c)
  end

  f = Waiter.new(project_info, ef_list)
  #f.print
  f.profile_to_html5
  #f.datapoints_to_csv
end
