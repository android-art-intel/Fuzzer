# Copyright (C) 2015 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#==========================================================
#  Java* Fuzzer for Android*
#  Statements that imply control transfer
#
# Authors: Mohammad R. Haghighat, Dmitry Khukhro, Andrey Yakovlev
#===============================================================================
# FOR statement
class ForLoopStmt < Statement
    attr_reader :inductionVar      # induction var of this loop

    def initialize(cont, par)
        #dputs("For loop creation!",true,10)
        super(cont, par, true, true)
        if (stmtsRemainder() < 2 or loopNesting() >= $conf.max_loop_depth)
            @emptyFlag = true
            return
        end
        @context = Context.new(cont, Con::STMT, cont.method) #Experimental
        @inductionVar = Var.new(@context, $conf.p_ind_var_type.getRand())
        @inductionVar.inductionVarFlag = true
        @step = $conf.for_step.getRand()
        indVars = ForLoopStmt.inductionVarsList(@parent)
        @maxVal = ForLoopStmt.indVarMaxValue(@parent, indVars)
        @initVal = (indVars.size > 0 and prob($conf.p_triang)) ? wrand(indVars) :
        (@maxVal.instance_of?(Var) ? 1 : mrand(@maxVal/$conf.start_frac) + 1)
        if @step < 0
            tmp = @initVal
            @initVal = @maxVal
            @maxVal = tmp
        end
        @nestedStmts["body"] = genStmtSeq($conf.max_loop_stmts, false) # at least 1 stmt
    end

    #------------------------------------------------------
    def gen
        ivar = @inductionVar.gen()
        if @initVal.instance_of?(Var)
            init = @initVal.gen()
            init = "(" + @inductionVar.type + ")" + init if typeGT?(@initVal.type, @inductionVar.type)
        else
            init = @initVal.to_s
        end
        max  = @maxVal.instance_of?(Var)  ? @maxVal.gen()  : @maxVal.to_s
        inc  = ((@step ==  1) ? "++" : " += " +    @step.to_s) if @step > 0
        inc  = ((@step == -1) ? "--" : " -= " + (-@step).to_s) if @step < 0
        res  = "for (" + ivar + " = " + init + "; "
        res += ivar +  (@step > 0 ? " < " : " > ") + max + "; "
        res  = ln(res + ((((inc == '++') or (inc == '--')) and prob(50)) ? inc + ivar : ivar + inc) + ") {")
        shift(1)
        res += @context.genDeclarations() # Experimental
        res += @nestedStmts["body"].collect{|st| st.gen()}.join()
        shift(-1)
        res + ln("}")
    end

    #------------------------------------------------------
    # returns list of loop induction vars in stmt hierarchy up from the given stmt
    def ForLoopStmt.inductionVarsList(stmt)
        res = []
        while (stmt)
            res << stmt.inductionVar if stmt.instance_of?(ForLoopStmt) or stmt.instance_of?(WhileDoStmt)
            stmt = stmt.parent
        end
        res
    end

    #------------------------------------------------------
    # returns random max value for a For or While or Do loop
    def ForLoopStmt.indVarMaxValue(par_stmt, indVars=nil)
        indVars = ForLoopStmt.inductionVarsList(par_stmt) unless indVars
        if (indVars.size > 0 and prob($conf.p_triang))
            res  = wrand(indVars)
        elsif indVars.size == 0 # this is top loop
            res = mrand($conf.max_size - 2 - ($conf.max_size * 3 / 4).to_i) + ($conf.max_size * 3 / 4).to_i + 1
        else
            res = mrand($conf.max_size - 2) + 1
        end
        res
    end
end

#===============================================================================
# WHILE and DO statements
class WhileDoStmt < Statement
    attr_reader :inductionVar      # induction var of this loop

    def initialize(cont, par)
        #dputs("While loop creation!",true,10)
        super(cont, par, true, true)
        if (stmtsRemainder() < 2 or loopNesting() >= $conf.max_loop_depth)
            @emptyFlag = true
            return
        end
        @context = Context.new(cont, Con::STMT, cont.method) #Experimental
        @kind = prob(50) ? 'while' : 'do'
        @inductionVar = Var.new(@context, $conf.p_ind_var_type.getRand())
        @inductionVar.inductionVarFlag = true
        @step = $conf.for_step.getRand()
        @maxVal = ForLoopStmt.indVarMaxValue(@parent)
        @nestedStmts["body"] = genStmtSeq($conf.max_loop_stmts, false) # at least 1 stmt
    end

    def gen
        if @maxVal.instance_of?(Var)
            max = @maxVal.gen()
            max = "(" + @inductionVar.type + ")" + max if typeGT?(@maxVal.type, @inductionVar.type)
        else
            max = @maxVal.to_s
        end
        ivar = @inductionVar.gen()
        inc  = (@step ==  1) ? "++" + ivar : "(" + ivar + " += " +    @step.to_s + ")" if @step > 0
        inc  = (@step == -1) ? "--" + ivar : "(" + ivar + " -= " + (-@step).to_s + ")" if @step < 0
        cond = @step > 0 ? " < " + max : " > 0"
        res  = ln(ivar + " = " + (@step > 0 ? '1' : max) + ";")
        res += ln((@kind == 'do' ? "do" : "while (" + inc + cond + ")") + " {")
        shift(1)
        res += @context.genDeclarations() # Experimental
        res += @nestedStmts["body"].collect{|st| st.gen()}.join()
        shift(-1)
        return res + ln("}") if @kind == 'while'
        res + ln("} while (" + inc + cond + ");")
    end
end

#===============================================================================
# Enhanced FOR statement
class EnhancedForStmt < Statement

    def initialize(cont, par)
        #dputs("Enhanced For loop creation!",true,10)
        super(cont, par, true, true)
        if (stmtsRemainder() < 2 or loopNesting() >= $conf.max_loop_depth)
            @emptyFlag = true
            return
        end
        @context = Context.new(cont, Con::STMT, cont.method)
        @param = Var.new(@context, $conf.types.getRand(TSET_ARITH), Nam::LOC)
        @targetArr = @context.getArr(100, @param.type, 1, false, nil, true)
        @nestedStmts["body"] = genStmtSeq($conf.max_loop_stmts, false) # at least 1 stmt
    end

    def gen
        res = ln("for (" + @param.type + " " + @param.gen() + " : " + @targetArr.name + ") {")
        shift(1)
        res += @context.genDeclarations() # Experimental
        res += @nestedStmts["body"].collect{|st| st.gen()}.join()
        shift(-1)
        res + ln("}")
    end
end
