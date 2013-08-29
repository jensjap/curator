require "test/unit"
require "./lib/environment"
require "./main"

load_rails_environment

class TestCurator < Test::Unit::TestCase

  def test_get_project_info  # {{{3
    assert_instance_of(Hash, get_project_info(135))
  end
  
  def test_get_extraction_forms  # {{{3
    assert_equal([190,193,194], get_extraction_forms(135))
  end
end
