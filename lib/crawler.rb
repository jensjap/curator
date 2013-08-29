class Crawler
  attr_reader :work_order, :error_stack

  def initialize(project_id, extraction_form_id)
    @work_order         = Array.new
    @error_stack        = Array.new
    @project_id         = project_id
    @ef_id              = extraction_form_id

    ## Entry point

    ## Section detail tables are of the following section:
    #    - Arm Detail
    #    - Baseline Characteristic
    #    - Design Detail
    #    - Outcome Detail
    #    - Quality Dimension
    self.crawl_section_details_table

    ## Extraction form arms tables are tables declared in the extraction form
    #  question section and made available to pick from when extracting data from
    #  a study. However, they only offer choices and there is no other relationship
    #  between these and the study extraction, i.e. an entry here is not necessary
    #  for the study extraction, but it will aid in figuring out what fields to scan
    #  when it comes time to import the data
    self.crawl_extraction_form_arms_table

    ## Extraction form outcome names table is just like the extraction form arms table.
    self.crawl_extraction_form_outcome_names
  end

  def crawl_section_details_table
    ["ArmDetail", "BaselineCharacteristic", "DesignDetail", "OutcomeDetail", "QualityDimension"].each do |section|
      if section == "QualityDimension"
        section_detail_fields = "#{section}Field".constantize.find_all_by_extraction_form_id(@ef_id)
        section_detail_fields.each do |section_detail_field|
          temp = {## My own bookkeeping
                  :section        => section,
                  :lookup_text    => "[#{section_detail_field.title}]",

                  ## Values from QualityDimensionField
                  :id                 => section_detail_field.id,
                  :question_text      => section_detail_field.title,
                  :field_notes        => section_detail_field.field_notes,
                  :extraction_form_id => section_detail_field.extraction_form_id,
                  :study_id           => section_detail_field.study_id,
                  :created_at         => section_detail_field.created_at,
                  :updated_at         => section_detail_field.updated_at,

                  ## Placeholders for QualityDimensionDataPoint entries
                  ## The plan is to iterate through each list element in :quality_dimension_data_point_fields
                  ## and collect the information as 1 unit and push it into :quality_dimension_data_points array
                  :quality_dimension_data_points       => [],
                  :quality_dimension_data_point_fields => {:"#{section.underscore}_field_id" => section_detail_field.id,  ## id of section detail. This field is 
                                                                                                                          ## used in the QualityDimensionDataPoint 
                                                                                                                          ## table but is incorrectly called 
                                                                                                                          ## quality_dimension_field_id instead of
                                                                                                                          ## being called quality_dimension_id
                                                           :value                            => nil,
                                                           :notes                            => nil,
                                                           :study_id                         => nil,
                                                           :field_type                       => nil,
                                                           :extraction_form_id               => @ef_id,
                                                           :created_at                       => nil,
                                                           :updated_at                       => nil,
                  },
          }
          @work_order.push(temp)
        end
      else
        section_details = "#{section}".constantize.find_all_by_extraction_form_id(@ef_id)
        section_details.each do |section_detail|
          ## "text" field_types are special in the sense that there is no entry for them in the section_detail_fields table.
          #  Therefore we cannot discover the count of these sections by iterating through the number of entries in the
          #  section_detail_fields table, but must add an entry into the work_order array immediately
          if section_detail.field_type.downcase == "text"
            temp = {## My own bookkeeping
                    :section        => section,
                    :lookup_text    => "[#{section_detail.question}]",

                    ## Values from Section
                    :id                      => section_detail.id,
                    :question_text           => section_detail.question,
                    :extraction_form_id      => section_detail.extraction_form_id,
                    :field_type              => section_detail.field_type,
# !!! BaselineCharacteristics calls this field_notes                    :field_note              => section_detail.field_note,
                    :question_number         => section_detail.question_number,
                    :study_id                => section_detail.study_id,
                    :created_at              => section_detail.created_at,
                    :updated_at              => section_detail.updated_at,
                    :instruction             => section_detail.instruction,
                    :is_matrix               => section_detail.is_matrix,
                    :include_other_as_option => section_detail.include_other_as_option,

                    ## Placeholders for the DataPoint table for each respective section
                    ## The plan is to iterate through each list element in :section_data_point_fields
                    ## and collect the information as 1 unit and push it into :quality_dimension_data_points array
                    :section_data_points => [],
                    :section_data_point_fields => {:"#{section.underscore}_field_id" => section_detail.id,  ## id of section detail. This field is 
                                                                                                            ## used in the SectionDataPoint 
                                                                                                            ## table but is incorrectly called 
                                                                                                            ## section_field_id instead of being called
                                                                                                            ## section_id
                                                   :value                            => nil,
                                                   :notes                            => nil,
                                                   :study_id                         => nil,
                                                   :extraction_form_id               => @ef_id,
                                                   :created_at                       => nil,
                                                   :updated_at                       => nil,
                                                   :arm_id                           => nil,
                                                   :subquestion_value                => nil,
                                                   :row_field_id                     => nil,                ## should always be 0 since this is never a matrix question
                                                   :column_field_id                  => nil,                ## should always be 0 since this is never a matrix question
                                                   :outcome_id                       => nil,
                    },
            }
            @work_order.push(temp)
          else
            section_detail_field_rows = "#{section}Field".constantize.find(:all, :conditions => {:"#{section.underscore}_id" => section_detail.id, :column_number => 0})
            section_detail_field_columns = "#{section}Field".constantize.find(:all, :conditions => {:"#{section.underscore}_id" => section_detail.id, :row_number => 0})
            section_detail_field_rows.each do |section_detail_field_row|
              ## If it is a matrix question we need to iterate through each column also
              if section_detail.is_matrix
                section_detail_field_columns.each do |section_detail_field_column|
                  temp = {## My own bookkeeping
                          :section        => section,
                          :lookup_text    => "[#{section_detail.question}][#{section_detail_field_row.option_text}][#{section_detail_field_column.option_text}]",
      
                          ## Values from Section
                          :id                      => section_detail.id,
                          :question_text           => section_detail.question,
                          :extraction_form_id      => section_detail.extraction_form_id,
                          :field_type              => section_detail.field_type,
# !!! BaselineCharacteristics calls this field_notes                    :field_note              => section_detail.field_note,
                          :question_number         => section_detail.question_number,
                          :study_id                => section_detail.study_id,
                          :created_at              => section_detail.created_at,
                          :updated_at              => section_detail.updated_at,
                          :instruction             => section_detail.instruction,
                          :is_matrix               => section_detail.is_matrix,
                          :include_other_as_option => section_detail.include_other_as_option,

                          ## Placeholders for the DataPoint table for each respective section
                          ## The plan is to iterate through each list element in :section_data_point_fields
                          ## and collect the information as 1 unit and push it into :quality_dimension_data_points array
                          :section_data_points => [],
                          :section_data_point_fields => {:"#{section.underscore}_field_id" => section_detail.id,  ## id of section detail. This field is 
                                                                                                                  ## used in the SectionDataPoint 
                                                                                                                  ## table but is incorrectly called 
                                                                                                                  ## section_field_id instead of being called
                                                                                                                  ## section_id
                                                         :value                            => nil,
                                                         :notes                            => nil,
                                                         :study_id                         => nil,
                                                         :extraction_form_id               => @ef_id,
                                                         :created_at                       => nil,
                                                         :updated_at                       => nil,
                                                         :arm_id                           => nil,
                                                         :subquestion_value                => nil,
                                                         :row_field_id                     => section_detail_field_row.id,     ## This refers to the id of the section detail field row
                                                         :column_field_id                  => section_detail_field_column.id,  ## This refers to the id of the section detail field column
                                                         :outcome_id                       => nil,
                                                         :option_text_row                  => section_detail_field_row.option_text,
                                                         :option_text_column               => section_detail_field_column.option_text,
                          }
                  }
                  @work_order.push(temp)
                end
              ## Otherwise just iterate through the rows
              else
              temp = {## My own bookkeeping
                      :section                 => section,
                      :lookup_text             => "[#{section_detail.question}][#{section_detail_field_row.option_text}]",

                      ## Values from Section
                      :id                      => section_detail.id,
                      :question_text           => section_detail.question,
                      :extraction_form_id      => section_detail.extraction_form_id,
                      :field_type              => section_detail.field_type,
# !!! BaselineCharacteristics calls this field_notes                    :field_note              => section_detail.field_note,
                      :question_number         => section_detail.question_number,
                      :study_id                => section_detail.study_id,
                      :created_at              => section_detail.created_at,
                      :updated_at              => section_detail.updated_at,
                      :instruction             => section_detail.instruction,
                      :is_matrix               => section_detail.is_matrix,
                      :include_other_as_option => section_detail.include_other_as_option,

                      ## Placeholders for the DataPoint table for each respective section
                      ## The plan is to iterate through each list element in :section_data_point_fields
                      ## and collect the information as 1 unit and push it into :quality_dimension_data_points array
                      :section_data_points => [],
                      :section_data_point_fields => {:"#{section.underscore}_field_id" => section_detail.id,  ## id of section detail. This field is 
                                                                                                              ## used in the SectionDataPoint 
                                                                                                              ## table but is incorrectly called 
                                                                                                              ## section_field_id instead of being called
                                                                                                              ## section_id
                                                     :value                            => nil,
                                                     :notes                            => nil,
                                                     :study_id                         => nil,
                                                     :extraction_form_id               => @ef_id,
                                                     :created_at                       => nil,
                                                     :updated_at                       => nil,
                                                     :arm_id                           => nil,
                                                     :subquestion_value                => nil,
                                                     :row_field_id                     => 0,
                                                     :column_field_id                  => 0,
                                                     :outcome_id                       => nil,
                                                     :option_text_row                  => section_detail_field_row.option_text,
                      }
              }
              @work_order.push(temp)
              end  #if section_detail.is_matrix
            end  #section_detail_field_rows.each do |section_detail_field_row|
          end  #if section_detail.field_type.downcase == "text"
        end  #section_details.each do |section_detail|
      end  #if section == "QualityDimension"
    end  #["ArmDetail", "BaselineCharacteristic", "DesignDetail", "OutcomeDetail"].each do |section|
  end

  def crawl_extraction_form_arms_table
    # !!! TODO
  end

  def crawl_extraction_form_outcome_names
    # !!! TODO
  end
end

