class ProgramNode
  def initialize()
    @lines = []
  end

  def evaluate()
    @lines.each {|line| line.evaluate()}
  end
end

class VariableNode
    attr_reader :name, :value, :type
    def initialize(name, value, type)
        @name = name
        @value = value
        @type = type
        @scope = nil
    end

    def set(value)
        @value = value
    end

    def value_type
      return @value.class.to_s
    end

    def evaluate()
      if(@value.class != ArrayNode)
        return @value
      else
        return @value.evaluate()
      end
    end

end

class ArithmeticNode

    def initialize(lh, op, rh)
        @lh = lh
        @rh = rh
        @op = op
        @value = nil
    end

    def evaluate()
        @value = @lh.evaluate().send(@op, @rh.evaluate())
        return @value
    end

    def value_type
      return @lh.evaluate().send(@op, @rh.evaluate()).class.to_s
    end
end

class IncrementNode

  def initialize(lh)
    @lh = lh
  end

  def evaluate()
    @lh.set(@lh.evaluate().send('+', 1))
  end

end

class IntegerNode
  attr_reader :value
  def initialize(value)
      @value = value
  end

  def evaluate()
      return @value
  end

  def value_type
    return @value.class.to_s
  end

  def +(other)
    return @value + other.value
  end
end

class FloatNode
    def initialize(value)
        @value = value
    end
  
    def evaluate()
        return @value
    end
  
    def value_type
      return @value.class.to_s
    end
end

class BoolNode
  def initialize(value)
    @value = value
  end

  def evaluate()
      return @value
  end

  def value_type
    return @value.class.to_s
  end
end

class BoolValueNode
  def initialize(value)
    @value = value
  end

  def evaluate()
      return @value
  end

  def value_type
    return @value.class.to_s
  end
end

class StringNode
  def initialize(value)
      value = value.split("\"")[1]
      @value = value
  end

  def evaluate()
    return @value
  end

  def value_type
    return @value.class.to_s
  end
end

class PrintNode
  def initialize(line)
    @line = line
  end

  def evaluate()
    puts @line.evaluate()
  end
end

class SplitNode
  def initialize(string)
    @string = string
    @value = nil
    list = Array.new
    @string.evaluate.each_char {|char| 
      c = StringNode.new("\"#{char}\"")
      list.append(c)
    }
    @value = ArrayNode.new(list)
  end

  def evaluate()
    return @value
  end
end


class ArrayNode
  attr_accessor :first_node

  #Our arrays are represented as a linked list of
  #ArrayElements

  def initialize(values)
    @first_node = nil
    @value = values

    if(@value != nil)
      @value.each {|element|
        node = ArrayElement.new(element)
        add_node(node)
      }
    end
  end

  def add_node(node) 
    if(@first_node != nil)
      current_node = @first_node
      while(current_node.next != nil)
        current_node = current_node.next
      end
      current_node.next = node
    else
      @first_node = node
    end
  end

  def value_type()
    return @value.class.to_s
  end

  def evaluate()
    list = []
    @value.each{|element|
      list.append(element.evaluate())
    }
    return "#{list}"
  end


end

class ArrayAccessorNode
  def initialize(var, index)
    @var = var
    @index = index
  end

  def evaluate()
    array = @var.value
    current_node = array.first_node
    @index.evaluate.times { 
      if(current_node.next != nil)
        current_node = current_node.next 
      end
    }
    if(current_node.value.class != ArrayNode)
      return current_node.value.evaluate()
    else
      return current_node.evaluate()
    end
  end
end
class ArrayElement
  attr_accessor :next, :value
  def initialize(value)
    @value = value
    @next = nil
  end

  def evaluate()
    return @value.evaluate
  end
end

class AssignmentNode

  attr_accessor :lh
  def initialize(lh, rh)
    @lh = lh
    @rh = rh
  end

  def evaluate()
    if(@rh.class != ArrayNode)
      @lh.set(@rh.evaluate)
    else
      @lh.set(@rh)
    end
  end
end

class FunctionNode
    attr_accessor :name, :parameters, :lines, :scope
  def initialize(name, params, *statements, scope)
    @name = name
    @parameters = params
    @lines = statements
    @scope = scope
  end

  def add_line(line)
    @lines.append(line)
  end

  def evaluate()
    @parameters.each {|param| scope.add_variable(param)}
    @lines.each {|line| 
      if(line.class == AssignmentNode && line.lh.class == VariableNode)
          @scope.add_variable(line.lh)
      end
    }
    return nil
  end
end

class FunctionCallNode

  def initialize(func_name, param_values, global_scope)
    @func = nil
    @func_name = func_name
    @param_values = param_values
    @global_scope = global_scope
    @return = nil

  end

  def evaluate()
    #Goes through global scope to find the right function
    @global_scope.functions.keys.each {|function|
      if(@global_scope.functions[function].name == @func_name)
        @func = @global_scope.functions[function]
        break
      end
    }

    @func.lines = @func.lines.flatten
    
    # Set the function-parameter variables to have the values 
    #specified in the function call parameters
    @func.parameters.each_with_index {|param, index|
      @func.scope.variables[param.object_id].set(@param_values[index].evaluate)
    }
    
    @func.lines.each {|line|
      #Checks if the current line is a return, in which case
      #the function stops executing
      if(line.class == ReturnNode) 
        @return = line
        break
      else
        if(line.class == IfStatementNode || line.class == ElseStatementNode || line.class == ForLoopNode)
          output = line.evaluate()
          #Checks to see if an if-statment, else-statement, etc returned a
          #ReturnNode
          if(output.class != ReturnNode)
            output
          else
            @return = output
            output
            break
          end
        else 
          #Otherwise, just evaluate the current line
          line.evaluate()
        end
      end
    }

    if(@return != nil)
      return @return.evaluate()
    else
      return nil
    end

  end

  def value_type()
    @return.evaluate().class.to_s
  end
end

class IfStatementNode
  attr_reader :alt_control_statement
  def initialize(conditions, *statements, scope, alt_control_statement)
    @conditions = conditions
    @lines = statements.flatten
    @scope = scope
    @alt_control_statement = alt_control_statement
  end

  def evaluate()
    #Checks if the if-condition is true
    if(@conditions[0].evaluate() == true)
      @lines.each {|line|
        output = line.evaluate()
        #Checks to see if the line itself isn't a ReturnNode,
        #and that output isn't a return node (if output is the result of
        #running a nested if-statement, etc) 
        if(line.class != ReturnNode && output.class != ReturnNode)
          output
        else
          if(line.class == ReturnNode)
            return line
          else
            return output
          end
        end
      }
    else
      #if the condition is false, check if there is
      #an else/else if statement attached to it
      if(@alt_control_statement != nil)
        @alt_control_statement.evaluate()
      else
        return nil
      end
    end
  end
  
end

class ElseStatementNode

  def initialize(*statements, scope)
    @lines = statements.flatten
    @scope = scope
  end

  def evaluate()
    @lines.each {|line|
      output = line.evaluate() 
      if(line.class != ReturnNode && output.class != ReturnNode)
        output
      else
        if(line.class == ReturnNode)
          return line
        else
          return output
        end
      end
    }
    return nil
  end
  
end


class LogicNode
  attr_reader :lh, :rh
  def initialize(lh, op, rh)
    @lh = lh
    @op = op
    @rh = rh
  end

  def evaluate()
    @lh.evaluate.send(@op, @rh.evaluate)
  end
end

class Scope
  attr_reader :variables, :functions, :parent
  def initialize(parent)
    @variables = {}
    @functions = {}
    @parent = parent
  end

  def add_variable(var)
    @variables[var.object_id] = var
  end

  def add_function(func)
    @functions[func.object_id] = func
  end
end

class AndNode
  attr_reader :lh, :rh
  def initialize(lh, rh)
    @lh = lh
    @rh = rh
  end

  def evaluate()
    @lh.evaluate() and @rh.evaluate()
  end
end

class OrNode
  attr_reader :lh, :rh

  def initialize(lh, rh)
    @lh = lh
    @rh = rh
  end

  def evaluate()
    @lh.evaluate() or @rh.evaluate()
  end
end

class ReturnNode
  attr_reader :value
  def initialize(value)
    @value = value
  end

  def evaluate()
    @value.evaluate()
  end
end

class ForLoopNode

  def initialize(control_variable, control_expression, operation, *statements, scope)
    @control_variable = control_variable
    @control_expression = control_expression
    @operation = operation
    @lines = statements.flatten
    @scope = scope
  end

  def evaluate()
    #Sets the control variable to the value specified
    @control_variable.evaluate()
    #Continually loops through the lines and increments the
    #control variable as long as the control expression
    #is true
    while(@control_expression.evaluate() == true)
      @lines.each {|line| line.evaluate()}
      @operation.evaluate()
    end
    return nil
  end

end

class WhileLoopNode

  def initialize(conditions, *statements, scope)
    @conditions = conditions

    @lines = statements.flatten
    @scope = scope
  end

  def evaluate()
    while(@conditions.evaluate() == true)
      @lines.each {|line| line.evaluate()}
    end
    return nil
  end
end