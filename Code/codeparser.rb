require './nodes.rb'
require './rdparse.rb'


$top_node = nil
$lines = []
$declaring_variable = false

$global_scope = Scope.new(nil)
$current_scope = $global_scope

class CodeParser

  def initialize
    @codeParser = Parser.new("dice roller") do
      token(/\s+/)
      
      #Reserved keywords
      token(/int/) {|m| m}
      token(/float/) {|m| m}
      token(/bool/) {|m| m}
      token(/string/) {|m| m}
      token(/array/) {|m| m}
      token(/def/) {|m| m}
      token(/end/) {|m| m}
      #-----------------

      #Specific matching for strings and floats
      token(/\d+/) {|m| m.to_i }
      token(/"[^"]*"/) {|m| m.to_s }
      token(/(\d+.\d+)/) {|m| m.to_f}

      
      #Reserved multi-character logic operators
      token(/!=/) {|m| m}
      token(/==/) {|m| m}
      token(/<=/) {|m| m}
      token(/=>/) {|m| m}

      token(/\+\+/) {|m| m} 
      token(/\-\-/) {|m| m} 

      token(/&&/) {|m| m}
      token(/\|\|/) {|m| m}

      token(/else if/) {|m| m}
      token(/else/) {|m| m}
      token(/for/) {|m| m}
      token(/while/) {|m| m}

      token(/return/) {|m| m}

      token(/[a-zA-Z]+/) {|m| m}
      token(/./) {|m| m }
      token(/;/) {|m| m }

      

    
      start :program do
          match(:statements) {|statements| 
            $lines.append(statements)
          }
      end

      rule :statements do
        match(:statements, :statement) {|statements, statement|
          [statements, statement].flatten
        }
        match(:statement) {|statement|
          statement
        }
      end
      
      rule :statement do

        match(:definition)

        

        match(:ariexpression, ';') {|ariexpression, _| 
          ariexpression
        }

        match(:variable, ';') {|variable, _|
          variable
        }
        match(:logicexpression, ';') {|logicexpression, _|
          logicexpression
        }
        match(:loop)

        match(:controlstatement)

        match('return', :ariexpression, ';') {|_, ariexpression, _| 
          re = ReturnNode.new(ariexpression)
        }

        match(:functioncall, ';')

        

        end

        rule :loop do
          match(:looptype, '(', :definition, :logicexpression, ';', :ariexpression, ')', '{', :statements, '}') {|looptype, _, var, logicexpression, _, operation, _, _, statements, _|
            #Checks the given loop type to see if the right keyword was used
            if(looptype != 'for')
              raise "Incorrect syntax: wrong loop type"
            end

            loop_scope = $current_scope
            
            #Removes lines defined in the loop body from the global scope lines
            if(statements.class == Array)
              statements.each {|statement|
                  $lines.delete(statement)
              }
            else
              $lines.delete(statements)
            end

            #Changes back the current scope to the previous scope
            $current_scope = $current_scope.parent

            #Creates a for-loop node
            ForLoopNode.new(var, logicexpression, AssignmentNode.new(var.lh, operation), statements, loop_scope)
            
          }
          match(:looptype, '(', :conditions, ')', '{', :statements, '}') {|looptype, _, conditions, _, _, statements, _|
            #Checks the given loop type to see if the right keyword was used
            if(looptype != 'while')
              raise "Incorrect syntax: wrong loop type"
            end
            
            #Creates a new variable holding the loop scope
            loop_scope = $current_scope
           
            #Removes lines defined in the loop body from the global scope lines
            if(statements.class == Array)
              statements.each {|statement|
                  $lines.delete(statement)
              }
            else
              $lines.delete(statements)
            end

            #Changes back the current scope to the previous scope
            $current_scope = $current_scope.parent
            
            #Creates a while-loop node
            WhileLoopNode.new(conditions, statements, loop_scope)
            
          }

        end

        rule :looptype do
          #Matches the initial key-word for a loop and sets up a new scope
          #as well as changing the current scope

          #This is done to ensure any variables, etc defined before the closing
          #bracket are added to the correct scope
          match('for') {|a| 
            scope = Scope.new($current_scope)
            $current_scope = scope
            a
          }
          match('while') {|a| 
            scope = Scope.new($current_scope)
            $current_scope = scope
            a
          }
        end

      
        rule :controlstatement do

          match(:controloperator, '{', :statements, '}') {|a, _, statements, _ |
            #Creates a new variable holding the control statement scope
            statement_scope = $current_scope
  
            #Removes lines defined in the control statement body from the global scope lines
            if(statements.class == Array)
              statements.each {|statement|
                  $lines.delete(statement)
              }
            else
              $lines.delete(statements)
            end

            #Switches back the current scope to be the previous one
            $current_scope = $current_scope.parent

            #Creates and returns an else-statement
            ElseStatementNode.new(statements, statement_scope)
          }

          match(:controloperator, '(', :conditions, ')', '{', :statements, '}', :controlstatement) {|a, _, *conditions, _, _, statements, _, alt_control_statement|
            #Creates a new variable holding the control statement scope
            statement_scope = $current_scope

            #Removes lines defined in the control statement body from the global scope lines
            if(statements.class == Array)
              statements.each {|statement|
                  $lines.delete(statement)
              }
            else
              $lines.delete(statements)
            end

            #Switches back the current scope to be the previous one
            $current_scope = $current_scope.parent.parent

            #Creates and returns an if-statement with an else if-statement
            IfStatementNode.new(conditions, statements, statement_scope, alt_control_statement)
        }

          match(:controloperator, '(', :conditions, ')', '{', :statements, '}') {|a, _, *conditions, _, _, statements, _|
            #Creates a new variable holding the control statement scope
            statement_scope = $current_scope
  
            #Removes lines defined in the control statement body from the global scope lines
            if(statements.class == Array)
              statements.each {|statement|
                  $lines.delete(statement)
              }
            else
              $lines.delete(statements)
            end
            #Switches back the current scope to be the previous one
            $current_scope = $current_scope.parent

            #Creates and returns an if-statement
            IfStatementNode.new(conditions, statements, statement_scope, nil)
          }
          
        end

      rule :controloperator do
        #Matches the initial key-word for a control statement and sets up a new scope
        #as well as changing the current scope

        #This is done to ensure any variables, etc defined before the closing
        #bracket are added to the correct scope
        match(/if/) {|a|
          scope = Scope.new($current_scope)
          $current_scope = scope
          a
        }

        match(/else if/) {|a|
          scope = Scope.new($current_scope)
          $current_scope = scope
          a
        }

        match(/else/) {|a|
          scope = Scope.new($current_scope)
          $current_scope = scope
          a
        }
      end

      rule :conditions do
        #Matches conditions in control statements and returns corresponding logical nodes
        match(:conditions, '&&', :logicexpression) {|conditions, _, logicexpression|
          AndNode.new(conditions, logicexpression)
        }
        match(:conditions, '||', :logicexpression) {|conditions, _, logicexpression|
          OrNode.new(conditions, logicexpression)
        }
        match(:logicexpression) {|logicexpression|
          logicexpression
        }
      end
      
      rule :definition do
        match(:variable, '=', :ariexpression, ';') {|var, _, ariexpression, _|

              #Adds the created variable to the current scope
              $current_scope.add_variable(var)
              #Creates and returns an assignment node which assigns the variable the given value at run-time
              AssignmentNode.new(var, ariexpression)
          
        }

        match(:functionstart, '(', :parameters, ')', :statements, 'end') {|func, _, *params, _, statements, _|
          #Flattens the list containing the parameters, as >2 parameters will give a multidimensional list
          params = params.flatten

          #Creates a variable holding the function scope
          func_scope = $current_scope

          #Adds the parameter variables as variables in the function scope as well
          params.each {|param| 
            func_scope.add_variable(param)
          }

          #Removes lines defined in the function body from the global scope
          if(statements.class == Array)
            statements.each {|statement|
                $lines.delete(statement)
            }
          else
            $lines.delete(statements)
          end

          #Adds the parameters and lines to the previously created FunctionNode
          func.parameters = params
          func.lines = [statements]

          #Changes back the current scope to the previous scope
          $current_scope = $current_scope.parent

          #Returns the FunctionNode
          func
        }
      end

      rule :functionstart do
        #Matches the initial key-word for a function definition and sets up a new scope
        #as well as changing the current scope

        #This is done to ensure any variables, etc defined before the closing
        #bracket are added to the correct scope
        match('def', :id) {|_, id| 
          scope = Scope.new($current_scope)
          $current_scope = scope

          func = FunctionNode.new(id, nil, nil, scope)

          $global_scope.add_function(func)

          func
        }
      end

      rule :parameters do
        #Matches several parameters, adding them to a list
        match(:parameter, ',', :parameters) {|param, _, params|
          #Adds all parameter variables as variables in the function's scope
          [param, params].flatten.each {|var| $current_scope.add_variable(var)}
          [param, params]
        }
        
        match(:parameter) {|param|
          $current_scope.add_variable(param)
          param
        }
      end

      rule :parameter do
        match(:variable)
      end

      rule :functioncall do
        match('split', '(', :string, ')') {|_, _, string, _|
          SplitNode.new(string)
        }

        match('print', '(', :ariexpression, ')') {|_, _, ariexpression, _, _|
          PrintNode.new(ariexpression)
        }

        match(:id, '(', :values, ')') {|func_name, _, *values, _|
          #Creates a one-dimensional list holding all parameter values
          values = values.flatten
          FunctionCallNode.new(func_name, values, $global_scope)
        }
        
      end

      rule :values do
        match(:value, ',', :values) {|value, _, values|
          [value, values]
        }
        
        match(:value)
      end

      rule :value do
        match(:ariexpression)
      end

      rule :logicexpression do
        match(:ariexpression, :oplogic, :ariexpression) {|lh, op ,rh|
          LogicNode.new(lh, op, rh)
        }
      end

      rule :oplogic do
        match(/==/) {|a| a}
        match(/!=/) {|a| a}

        match(/<=/) {|a| a}
        match(/=>/) {|a| a}

        match(/</) {|a| a}
        match(/>/) {|a| a}
      end

      rule :ariexpression do
        match(:ariterm, '+', :ariexpression) {|ariterm, op, ariexpression| 
          ArithmeticNode.new(ariterm, op, ariexpression)
        }
        match(:ariterm, '-', :ariexpression) {|ariterm, op, ariexpression| 
          ArithmeticNode.new(ariterm, op, ariexpression)
        }
        match(:id, '++') {|id, _|
          ArithmeticNode.new(id, '+', IntegerNode.new(1))

        }
        match(:id, '--') {|id, _|
          ArithmeticNode.new(id, '-', IntegerNode.new(1))

        }
        match(:ariterm)
      end

      rule :ariterm do
        match(:atom, '*', :ariterm) {|atom, op, ariterm| 
          ArithmeticNode.new(atom, op, ariterm)
        }
        match(:atom, '/', :ariterm) {|atom, op, ariterm| 
          ArithmeticNode.new(atom, op, ariterm)
        }
        match(:atom, '^', :ariterm) {|atom, _, ariterm| 
          ArithmeticNode.new(atom, '**', ariterm)
        }
        match(:atom) {|a| a}

      end

      rule :atom do
        match(:array)
        match(:string) 
        match(:number)
        match(:bool)
        match(:functioncall)
        match(:variable)
        match('(', :ariexpression, ')') {|_, ariexpression, _| ariexpression}
      end

      rule :number do
        match(Integer) {|number| 
          
          IntegerNode.new(number)
        }
        match(Float) {|number| 
            
            FloatNode.new(number)
        }
    end

      rule :string do
        match(/"[^"]*"/) {|string|
          StringNode.new(string)
        }
      end

      rule :array do
        match(:id, '[', :number, ']') {|id, _, number, _|
          ArrayAccessorNode.new(id, number)
        }
        match('[', :values, ']') {|_, *values, _|
          values = values.flatten
          ArrayNode.new(values)
        }
      end

      rule :bool do
        match(/true/) {|value|
          BoolValueNode.new(true)
        }
        match(/false/) {|value|
          BoolValueNode.new(false)
        }
      end

      rule :variable do
        match(:type, :id) {|type, id| 
            if(type == 'int')
                VariableNode.new(id, 0, 'Integer')
            elsif(type == 'float')
                VariableNode.new(id, 0, 'Float')
            elsif(type == 'bool')
                VariableNode.new(id, 0, 'Bool')
            elsif(type == 'string')
                VariableNode.new(id, "", 'String')
            elsif(type == 'array')
                VariableNode.new(id, [], 'Array')
            end
        }
        
        match(:id)
      end

      rule :type do
        match(/int/) {|a| 
          $declaring_variable = true  
          a
        }
        match(/float/) {|a| 
          $declaring_variable = true
          a
        }
        match(/bool/) {|a| 
          $declaring_variable = true
          a
        }
        match(/string/) {|a| 
          $declaring_variable = true  
          a
        }
        match(/array/) {|a| 
          $declaring_variable = true  
          a
        }
      end

      rule :id do
        match(/[a-zA-Z]+/) {|id|
          #is_variable = false
          variable = nil
          scope = $current_scope

          if($declaring_variable)

            scope.variables.keys.each {|var|
              if(scope.variables[var].name == id)
                raise "Re-declaring pre-existing variable"
                break
              end
            }

          else

            while(variable == nil && scope != nil)
              scope.variables.keys.each {|var|
                if(scope.variables[var].name == id)
                  variable = scope.variables[var]
                  break
                end
              }

              scope = scope.parent

            end
          end

          $declaring_variable = false

          if(variable != nil)
            variable
          else
            id
          end
        }
      end
    end
  end
  
  def done(str)
  end
  
  def parse(file)
    str = File.open(file)
    code = ""
    if done(str) then
      puts "Bye."
    else
      str.each { |line|
        code += line
      }
      @codeParser.parse code 

    end
  end

  def log(state = false)
    if state
      @codeParser.logger.level = Logger::DEBUG
    else
      @codeParser.logger.level = Logger::WARN
    end
  end
end

CodeParser.new.parse("test.pvp")

$lines.flatten!

$lines.each {|line|
  line.evaluate()
}