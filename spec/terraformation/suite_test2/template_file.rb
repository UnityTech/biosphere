
def helper_function(variable)
	resource "type", "name1",
		foo: "I'm #{variable}"

end

def my_template(variable)

	helper_function(variable)

	resource "type", "name2" do
		property "test"
	end

end
