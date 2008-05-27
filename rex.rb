require 'pathname'

def add_macro(line, macro_list)
	if line =~ /\A\w+/
		new_macro_name="{#{$&}}"
		new_macro_text=$'.rstrip.strip
		macro_list << [new_macro_name,new_macro_text]
	end
end
def add_regexp(line, regexp_list, macro_list)
 	macro_list.each{|macro|	line=line.gsub(macro[0], macro[1])}
	if line =~ /\s*:\s*/
		new_regexp="\\A"+$`
		new_token=$'.strip
		regexp_list << [Regexp.new(new_regexp),new_token]
	end
end

if ARGV.size!=1
	puts "usage: #{__FILE__} rex_file"
	exit
end

text=File.open(ARGV[0], "r"){|file| file.read}

phase=0
macro_list=[]
regexp_list=[]
text.each_line do |line|
	phase += 1 if /\A%%.*/ === line
	case phase
		when 0: add_macro(line, macro_list)
		when 1: add_regexp(line, regexp_list, macro_list)
	end
end

regexp_commands=""
regexp_identifiers=""
tabs="\t\t\t\t\t"
regexp_list.each_index do |index|
	regexp=regexp_list[index]

	regexp_identifiers+="\t\t\t\tregexp_candidates<<[#{index},$&.length] if str =~ #{regexp[0].inspect}\n"

	regexp_commands+="#{tabs}when #{index}\n"
	regexp_commands+="#{tabs}\tstr =~ #{regexp[0].inspect}\n"
	regexp_commands+="#{tabs}\t@q.push [#{regexp[1].to_sym.inspect},$&]\n" if regexp[1]!=""
	regexp_commands+="#{tabs}\tstr = $'\n"
end

parser_code = <<END_PARSER_CODE
module Rex
	class Lexer
		def parse(str)
			str = str.strip
			@q = []
			until str.empty?
				regexp_candidates=[]
#{regexp_identifiers}
				regexp_candidates.sort! do |a,b|
					if a[1]==b[1]
						a[0]<=>b[0]
					else
						a[1]<=>b[1]
					end
				end
				unless regexp_candidates.empty?
					case regexp_candidates.last[0]
#{regexp_commands}
					end
				else
					c = str[0,1]
					@q.push([c,:rex_error_symbol])
					str = str[1..-1]
				end
			end
		end
		def next_token
			result=@q.shift
			return result if result==nil
			if result[1]==:rex_error_symbol
				error(result[0])
				return nil
			end
			return result
		end
		def error(c)
			puts(c)
		end
		def run
			parse(gets)
			while not @q.empty?
				token=next_token
				puts token.inspect unless token == nil
			end
		end
	end
end

Rex::Lexer.new.run if $0 == __FILE__
END_PARSER_CODE

input_file = Pathname.new(ARGV[0])
output_filename = \
  (input_file.dirname + input_file.basename(".rex")).to_s + ".rb"

File.open(output_filename, "w") { |file| file.write(parser_code) }
