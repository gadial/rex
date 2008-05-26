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
tabs="\t\t\t\t\t"
regexp_list.each do |regexp|
	regexp_commands+="#{tabs}when #{regexp[0].inspect}\n"
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
				case str
#{regexp_commands}					else
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

File.open(ARGV[0].sub(".rex",".rb"),"w"){|file| file.write(parser_code)}