defmodule NervesHubWeb.OrgUserViewTest do
  use NervesHubWeb.ConnCase, async: true

  alias NervesHubWeb.OrgUserView

  describe "role_options/0" do
    test "a list of formatted tuples is returned" do
      assert OrgUserView.role_options() == [
               {"Admin", :admin},
               {"Delete", :delete},
               {"Write", :write},
               {"Read", :read}
             ]
    end
  end
end
