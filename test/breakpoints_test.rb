require_relative 'test_helper'

describe "Breakpoints" do
  include TestDsl

  describe "setting breakpoint in the current file" do
    before { enter 'break 10' }
    subject { breakpoint }

    def check_subject(field, value)
      debug_file("breakpoint1") { subject.send(field).must_equal value }
    end

    it("must have correct pos") { check_subject(:pos, 10) }
    it("must have correct source") { check_subject(:source, fullpath("breakpoint1")) }
    it("must have correct expression") { check_subject(:expr, nil) }
    it("must have correct hit count") { check_subject(:hit_count, 0) }
    it("must have correct hit value") { check_subject(:hit_value, 0) }
    it("must be enabled") { check_subject(:enabled?, true) }
    it("must return right response") do
      id = nil
      debug_file('breakpoint1') { id = subject.id }
      check_output_includes "Breakpoint #{id} file #{fullpath('breakpoint1')}, line 10"
    end

    describe "Xml" do
      temporary_change_method_value(Debugger, :printer, Printers::Xml.new)

      it "must return right response" do
        id = nil
        debug_file('breakpoint1') { id = subject.id }
        check_output_includes "<breakpointAdded no=\"#{id}\" location=\"#{fullpath('breakpoint1')}:10\"/>"
      end
    end
  end


  describe "using shortcut for the command" do
    before { enter 'b 10' }
    it "must set a breakpoint" do
      debug_file("breakpoint1") { Debugger.breakpoints.size.must_equal 1 }
    end
  end


  describe "setting breakpoint to unexisted line" do
    before { enter 'break 100' }

    it "must not create a breakpoint" do
      debug_file("breakpoint1") { Debugger.breakpoints.must_be_empty }
    end

    describe "show an error" do
      it "in plain text" do
        debug_file("breakpoint1")
        check_output_includes "There are only #{LineCache.size(fullpath('breakpoint1'))} lines in file 'breakpoint1.rb'", interface.error_queue
      end

      it "in xml" do
        temporary_change_method_value(Debugger, :printer, Printers::Xml.new) do
          debug_file("breakpoint1")
          check_output_includes "<error>There are only 15 lines in file 'breakpoint1.rb'</error>", interface.error_queue
        end
      end
    end
  end


  describe "stopping at breakpoint" do
    it "must stop at the correct line" do
      enter 'break 14', 'cont'
      debug_file("breakpoint1") { state.line.must_equal 14 }
    end

    it "must stop at the correct file" do
      enter 'break 14', 'cont'
      debug_file("breakpoint1") { state.file.must_equal fullpath("breakpoint1") }
    end

    describe "show a message" do
      temporary_change_hash_value(Debugger::Command.settings, :basename, false)

      describe "in plain text" do
        it "must show a message with full filename" do
          enter 'break 14', 'cont'
          debug_file("breakpoint1")
          check_output_includes "Breakpoint 1 at #{fullpath('breakpoint1')}:14"
        end

        it "must show a message with basename" do
          enter 'set basename', 'break 14', 'cont'
          debug_file("breakpoint1")
          check_output_includes "Breakpoint 1 at breakpoint1.rb:14"
        end
      end

      describe "in xml" do
        temporary_change_method_value(Debugger, :printer, Printers::Xml.new)

        it "must show a message with full filename" do
          enter 'break 14', 'cont'
          debug_file("breakpoint1")
          check_output_includes "<breakpoint file=\"#{fullpath('breakpoint1')}\" line=\"14\" threadId=\"1\"/>"
        end

        it "must show a message with basename" do
          enter 'set basename', 'break 14', 'cont'
          debug_file("breakpoint1")
          check_output_includes "<breakpoint file=\"breakpoint1.rb\" line=\"14\" threadId=\"1\"/>"
        end

        it "must not show <suspended>" do
          enter 'break 14', 'cont'
          debug_file("breakpoint1")
          check_output_doesnt_include /<suspended[^>]+line="14"/
        end
      end
    end
  end


  describe "set breakpoint in a file" do
    describe "successfully" do
      before do
        enter "break #{fullpath('breakpoint2')}:3", 'cont'
      end

      it "must stop at the correct line" do
        debug_file("breakpoint1") { state.line.must_equal 3 }
      end

      it "must stop at the correct file" do
        debug_file("breakpoint1") { state.file.must_equal fullpath("breakpoint2") }
      end
    end

    describe "when setting breakpoint to unexisted file" do

      describe "in plain text" do
        before do
          enter "break asf:324"
          debug_file("breakpoint1")
        end

        it "must show an error" do
          check_output_includes "No source file named asf", interface.error_queue
        end

        it "must ask about setting breakpoint anyway" do
          check_output_includes "Set breakpoint anyway? (y/n)", interface.confirm_queue
        end
      end

      describe "in xml" do
        temporary_change_method_value(Debugger, :printer, Printers::Xml.new)
        before do
          enter "break asf:324"
          debug_file("breakpoint1")
        end

        it "must show an error" do
          check_output_includes "<error>No source file named asf</error>", interface.error_queue
        end

        it "must ask about setting breakpoint anyway" do
          check_output_includes "<confirmation>Set breakpoint anyway?</confirmation>", interface.confirm_queue
        end
      end

    end
  end


  describe "set breakpoint to a method" do
    describe "set breakpoint to an instance method" do
      before do
        enter 'break A#b', 'cont'
      end

      it "must stop at the correct line" do
        debug_file("breakpoint1") { state.line.must_equal 5 }
      end

      it "must stop at the correct file" do
        debug_file("breakpoint1") { state.file.must_equal fullpath("breakpoint1") }
      end

      describe "messages" do
        it "must show in plain text" do
          id = nil
          debug_file("breakpoint1") { id = breakpoint.id }
          check_output_includes "Breakpoint #{id} at A::b"
        end

        it "must show in xml" do
          temporary_change_method_value(Debugger, :printer, Printers::Xml.new) do
            id = nil
            debug_file("breakpoint1") { id = breakpoint.id }
            check_output_includes "<breakpointAdded no=\"#{id}\" method=\"A::b\"/>"
          end
        end
      end
    end

    describe "set breakpoint to a class method" do
      before do
        enter 'break A.a', 'cont'
      end

      it "must stop at the correct line" do
        debug_file("breakpoint1") { state.line.must_equal 2 }
      end

      it "must stop at the correct file" do
        debug_file("breakpoint1") { state.file.must_equal fullpath("breakpoint1") }
      end
    end

    describe "set breakpoint to unexisted class" do
      describe "in plain text" do
        it "must show an error" do
          enter "break B.a"
          debug_file("breakpoint1")
          check_output_includes "Unknown class B", interface.error_queue
        end
      end

      describe "in xml" do
        temporary_change_method_value(Debugger, :printer, Printers::Xml.new)

        it "must show an error" do
          enter "break B.a"
          debug_file("breakpoint1")
          check_output_includes "<error>Unknown class B</error>", interface.error_queue
        end
      end
    end
  end


  describe "set breakpoint to an invalid location" do
    before { enter "break foo" }

    it "must not create a breakpoint" do
      debug_file("breakpoint1") { Debugger.breakpoints.must_be_empty }
    end

    describe "in plain text" do
      it "must show an error" do
        debug_file("breakpoint1")
        check_output_includes 'Invalid breakpoint location: foo', interface.error_queue
      end
    end

    describe "in xml" do
      temporary_change_method_value(Debugger, :printer, Printers::Xml.new)

      it "must show an error" do
        debug_file("breakpoint1")
        check_output_includes '<error>Invalid breakpoint location: foo</error>', interface.error_queue
      end
    end
  end


  describe "disabling a breakpoint" do
    describe "successfully" do
      before { enter "break 14" }

      describe "short syntax" do
        before { enter ->{"disable #{breakpoint.id}"}, "break 15" }
        it "must have a breakpoint with #enabled? returning false" do
          debug_file("breakpoint1") { breakpoint.enabled?.must_equal false }
        end

        it "must not stop on the disabled breakpoint" do
          enter "cont"
          debug_file("breakpoint1") { state.line.must_equal 15 }
        end

        describe "messaging" do
          it "must show success message in plain text" do
            id = nil
            debug_file("breakpoint1") { id = breakpoint.id }
            check_output_includes "Breakpoint #{id} is disabled"
          end

          it "must show success message in xml" do
            temporary_change_method_value(Debugger, :printer, Printers::Xml.new) do
              id = nil
              debug_file("breakpoint1") { id = breakpoint.id }
              check_output_includes "<breakpointDisabled bp_id=\"#{id}\"/>"
            end
          end
        end
      end

      describe "full syntax" do
        before { enter ->{"disable breakpoints #{breakpoint.id}"}, "break 15" }
        it "must have a breakpoint with #enabled? returning false" do
          debug_file("breakpoint1") { breakpoint.enabled?.must_equal false }
        end
      end
    end

    describe "errors" do
      describe "in plain text" do
        it "must show an error if syntax is incorrect" do
          enter "disable"
          debug_file("breakpoint1")
          check_output_includes(
            "'disable' must be followed 'display', 'breakpoints' or breakpoint numbers",
            interface.error_queue
          )
        end

        it "must show an error if no breakpoints is set" do
          enter "disable 1"
          debug_file("breakpoint1")
          check_output_includes 'No breakpoints have been set', interface.error_queue
        end

        it "must show an error if not a number is provided as an argument to 'disable' command" do
          enter "break 14", "disable foo"
          debug_file("breakpoint1")
          check_output_includes "Disable breakpoints argument 'foo' needs to be a number"
        end
      end

      describe "in xml" do
        temporary_change_method_value(Debugger, :printer, Printers::Xml.new)

        it "must show an error if syntax is incorrect" do
          enter "disable"
          debug_file("breakpoint1")
          check_output_includes(
            "<error>'disable' must be followed 'display', 'breakpoints' or breakpoint numbers</error>",
            interface.error_queue
          )
        end

        it "must show an error if no breakpoints is set" do
          enter "disable 1"
          debug_file("breakpoint1")
          check_output_includes '<error>No breakpoints have been set</error>', interface.error_queue
        end

        it "must show an error if not a number is provided as an argument to 'disable' command" do
          enter "break 14", "disable foo"
          debug_file("breakpoint1")
          check_output_includes "<error>Disable breakpoints argument 'foo' needs to be a number</error>"
        end
      end
    end
  end


  describe "enabling a breakpoint" do
    describe "successfully" do
      before { enter "break 14" }
      describe "short syntax" do
        before { enter ->{"enable #{breakpoint.id}"}, "break 15" }

        it "must have a breakpoint with #enabled? returning true" do
          debug_file("breakpoint1") { breakpoint.enabled?.must_equal true }
        end

        it "must stop on the enabled breakpoint" do
          enter "cont"
          debug_file("breakpoint1") { state.line.must_equal 14 }
        end

        describe "messaging" do
          it "must show success message in plain text" do
            id = nil
            debug_file("breakpoint1") { id = breakpoint.id }
            check_output_includes "Breakpoint #{id} is enabled"
          end

          it "must show success message in xml" do
            temporary_change_method_value(Debugger, :printer, Printers::Xml.new) do
              id = nil
              debug_file("breakpoint1") { id = breakpoint.id }
              check_output_includes "<breakpointEnabled bp_id=\"#{id}\"/>"
            end
          end
        end
      end

      describe "full syntax" do
        before { enter ->{"enable breakpoints #{breakpoint.id}"}, "break 15" }

        it "must have a breakpoint with #enabled? returning true" do
          debug_file("breakpoint1") { breakpoint.enabled?.must_equal true }
        end
      end
    end

    describe "errors" do
      describe "in plain text" do
        it "must show an error if syntax is incorrect" do
          enter "enable"
          debug_file("breakpoint1")
          check_output_includes(
            "'enable' must be followed 'display', 'breakpoints' or breakpoint numbers",
            interface.error_queue
          )
        end
      end

      describe "in xml" do
        temporary_change_method_value(Debugger, :printer, Printers::Xml.new)
        it "must show an error if syntax is incorrect" do
          enter "enable"
          debug_file("breakpoint1")
          check_output_includes(
            "<error>'enable' must be followed 'display', 'breakpoints' or breakpoint numbers</error>",
            interface.error_queue
          )
        end
      end
    end
  end


  describe "deleting a breakpoint" do
    before do
      @breakpoint_id = nil
      enter "break 14", ->{@breakpoint_id = breakpoint.id; "delete #{@breakpoint_id}"}, "break 15"
    end

    it "must have only one breakpoint" do
      debug_file("breakpoint1") { Debugger.breakpoints.size.must_equal 1 }
    end

    it "must not stop on the disabled breakpoint" do
      enter "cont"
      debug_file("breakpoint1") { state.line.must_equal 15 }
    end

    describe "messaging" do
      it "must show a success message in plain text" do
        debug_file("breakpoint1")
        check_output_includes "Breakpoint #{@breakpoint_id} has been deleted"
      end

      it "must show a success message in xml" do
        temporary_change_method_value(Debugger, :printer, Printers::Xml.new) do
          debug_file("breakpoint1")
          check_output_includes "<breakpointDeleted no=\"#{@breakpoint_id}\"/>"
        end
      end
    end
  end


  describe "Conditional breakpoints" do
    it "must stop if the condition is correct" do
      enter "break 14 if b == 5", "break 15", "cont"
      debug_file("breakpoint1") { state.line.must_equal 14 }
    end

    it "must skip if the condition is incorrect" do
      enter "break 14 if b == 3", "break 15", "cont"
      debug_file("breakpoint1") { state.line.must_equal 15 }
    end

    describe "show an error when conditional syntax is wrong" do
      it "must show in plain text" do
        enter "break 14 ifa b == 3", "break 15", "cont"
        debug_file("breakpoint1") { state.line.must_equal 15 }
        check_output_includes "Expecting 'if' in breakpoint condition; got: ifa b == 3", interface.error_queue
      end

      it "must show in xml" do
        temporary_change_method_value(Debugger, :printer, Printers::Xml.new) do
          enter "break 14 ifa b == 3", "break 15", "cont"
          debug_file("breakpoint1") { state.line.must_equal 15 }
          check_output_includes(
            "<error>Expecting 'if' in breakpoint condition; got: ifa b == 3</error>",
            interface.error_queue
          )
        end
      end
    end

    describe "enabling with wrong conditional syntax" do
      before do
        enter(
          "break 14",
          ->{"disable #{breakpoint.id}"},
          ->{"cond #{breakpoint.id} b -=( 3"},
          ->{"enable #{breakpoint.id}"}
        )
      end

      it "must not enable a breakpoint" do
        debug_file("breakpoint1") { breakpoint.enabled?.must_equal false }
      end

      describe "show an error" do
        it "must show in plain text" do
          debug_file("breakpoint1")
          check_output_includes(
            "Expression 'b -=( 3' syntactically incorrect; breakpoint remains disabled",
            interface.error_queue
          )
        end

        it "must show in plain text" do
          temporary_change_method_value(Debugger, :printer, Printers::Xml.new) do
            debug_file("breakpoint1")
            check_output_includes(
              "<error>Expression 'b -=( 3' syntactically incorrect; breakpoint remains disabled</error>",
              interface.error_queue
            )
          end
        end
      end
    end

    describe "in plain text" do
      it "must show an error if no file or line is specified" do
        enter "break ifa b == 3", "break 15", "cont"
        debug_file("breakpoint1") { state.line.must_equal 15 }
        check_output_includes "Invalid breakpoint location: ifa b == 3", interface.error_queue
      end

      it "must show an error if expression syntax is invalid" do
        enter "break if b -=) 3", "break 15", "cont"
        debug_file("breakpoint1") { state.line.must_equal 15 }
        check_output_includes "Expression 'b -=) 3' syntactically incorrect; breakpoint disabled", interface.error_queue
      end
    end

    describe "in xml" do
      temporary_change_method_value(Debugger, :printer, Printers::Xml.new)

      it "must show an error if no file or line is specified" do
        enter "break ifa b == 3", "break 15", "cont"
        debug_file("breakpoint1") { state.line.must_equal 15 }
        check_output_includes "<error>Invalid breakpoint location: ifa b == 3</error>", interface.error_queue
      end

      it "must show an error if expression syntax is invalid" do
        enter "break if b -=) 3", "break 15", "cont"
        debug_file("breakpoint1") { state.line.must_equal 15 }
        check_output_includes(
          "<error>Expression 'b -=) 3' syntactically incorrect; breakpoint disabled</error>",
          interface.error_queue
        )
      end
    end
  end


  describe "Post Mortem" do
    it "must be able to set breakpoints in post-mortem mode" do
      enter 'cont', 'break 12', 'cont'
      debug_file("post_mortem") { state.line.must_equal 12 }
    end
  end

end
