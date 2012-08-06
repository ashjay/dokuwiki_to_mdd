#-------------------------------------------------------------------------------------------------------
#----------------- UPLOAD ------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------------------------

desc "Create sheets from dokuwiki_pages"
task :upload_sheets => :environment do 
	#if(File.directory?"public/dokuwiki_pages")
	contains = Dir.entries("public/dokuwiki_pages")
	i=0
	Dir.chdir("public/dokuwiki_pages/")
	contains.each do |c|
		#puts c
		content =""
		if(File.directory?("#{c}") && c.match(/^\w.*$/))
			begin
				Dir.chdir("#{c}") do 	
					if(File.file?"index.html")
						f = File.open("index.html", "r")
						f.each_line {|line|
							content << line
						}
						f.close
						create_new_sheet("#{c}", content, 1)
						#STDOUT.flush
						puts "#{c}"
					
						i= i+1
					end		
				end
			rescue Exception => e
				puts "Probleme with the sheet #{c} : #{e}"	
			end			
		end	
	end	
	puts "\n #{i} sheets Uploaded"

end

#FUNCTION TO CREATE NEW SHEET
def create_new_sheet(title,description,level)
	sheet = Sheet.new
	sheet.title = title
	if(level.to_s.match(/[1-3]/))
		sheet.level = level
	else 
		sheet.level = 1	
	end	
	sheet.keywords << Keyword.first
	sheet.description = description
	sheet.save
end	

desc"Upload all pictures from public/dokuwiki_pages/imgs "
task :upload_images  => :environment do
	#Dir.chdir("public/dokuwiki_pages/")
	if File.directory?("imgs")
		begin
			pictures = Dir.entries("imgs")
			Dir.chdir("imgs")
			pictures.each do |picture|
				if(picture.match(/^\w.*\.(jpg|png|gif)$/) && File.size?("#{picture}")) # the file shouldn't be empty
					pict = Ckeditor::Picture.new
					#puts picture
					pict.data = File.new("#{picture}")
					pict.save
				end
			end	
		rescue Exception => e
			puts "#{e}"
		end	
	else
		puts "false"	
	end	
	puts "Images Uploaded"
end	


desc"Upload all attachments from public/dokuwiki_pages/pj"
task :upload_attachments => :environment do 
	#Dir.chdir("public/dokuwiki_pages/")
	if File.directory?("../pj")
		begin
			attachments = Dir.entries("../pj")
			Dir.chdir("../pj")
			attachments.each do |pj|
				if(pj.match(/^\w.*\..*$/) && File.size?("#{pj}")) # the file shouldn't be empty
					attachment = Ckeditor::AttachmentFile.new
					puts attachment
					attachment.data = File.new("#{pj}")
					attachment.save
				end
			end	
		rescue Exception => e
			puts "#{e}"
		end	
	else
		puts "false"	
	end	
end

#-------------------------------------------------------------------------------------------------------
#----------------- CORRECT LINKS -----------------------------------------------------------------------
#-------------------------------------------------------------------------------------------------------
desc "correct the image lings in html sheets"
task :correct_links => :environment do
	Sheet.all.each do |s|
		if(s.description)
			s.description = get_image_links(s.description)
			s.description = get_attachment_links(s.description)	
			s.description = get_sheet_links(s.description)	
			s.save
		end	
	end
end



def get_attachment_links(text_to_parse)
		attachment_url = text_to_parse.scan(/href=".*?\.pdf|odt|zip"/)
		attachment_url.each do |pj|
		 	if(!pj.blank?)
		 		puts pj
		 		attachment_name = pj.gsub(/"/,"").split(":").last 
		 		begin
					attachment = Ckeditor::AttachmentFile.find_by_data_file_name("#{attachment_name}")
		 			puts attachment_name.to_s
		 			puts attachment.id
		 			#puts text_to_parse.match(/href=".*?#{attachment_name}/)
		 			text_to_parse = text_to_parse.sub(/href=".*?#{attachment_name}"/, 
		 				"href=\"/system/ckeditor_assets/attachments/#{attachment.id}/#{attachment_name}\"")		 			
		 		rescue Exception => e
		 			puts "#{e}"
		 		end		
		 	end	
		end		
	return text_to_parse
end


def get_image_links(text_to_parse)
		image_url = text_to_parse.scan(/src=".*?"/)
		image_url.each do |img|
		 	if(!img.blank?)	
		 		image_name = img.gsub(/"/,"").split(":").last 
		 		begin
					pic = Ckeditor::Picture.find_by_data_file_name("#{image_name}")
		 			puts image_name.to_s
		 			puts pic.id
		 			text_to_parse = text_to_parse.sub(/src=".*?#{image_name}"/, "src=\"/system/ckeditor_assets/pictures/#{pic.id}/#{image_name}\"")		 			
		 		rescue Exception => e
		 			puts "#{e}"
		 		end		
		 	end	
		end		
	return text_to_parse
end


def get_sheet_links(text_to_parse)
page_links = text_to_parse.scan(/href="\/doku.php\?id=.*?"/)
		if(!page_links.blank?)
			page_links.each do |pl|
				#puts pl
				page_title = pl.gsub(/"/,"").split("id=").last.to_s
				puts "\t...........#{page_title.to_s}"
				begin
					page = Sheet.find_by_title("#{page_title}")
					puts "\t#{page.title} --- #{page.id}"
					text_to_parse=text_to_parse.sub(/href="\/doku.php\?id=#{page_title}"/,
						"href=\"http://localhost:3000/sheets/#{page.id}\"")
			 	rescue	Exception => e
			 		puts "\t\t..............#{e}"
			 		text_to_parse = text_to_parse.gsub(/href="\/doku.php\?id=#{page_title}"/, 
		 				"href=\"\" style=\"color:red\"")
			 	end	 
			end	
		end	
	return text_to_parse	
end




#-------------------------------------------------------------------------------------------------------
#----------------- MIGRATION --- -----------------------------------------------------------------------
#-------------------------------------------------------------------------------------------------------

desc "Upload sheets with attachments and pictures"
task :migrate_sheets => [:upload_sheets, :upload_images, :upload_attachments, :correct_links]

desc "Reset the database "
task :reinit_database => :environment do 
	begin 
		Rake::Task["db:drop"].invoke
		%x(curl -XDELETE 'http://localhost:9200/mdd-development_sheets')
	rescue Exception => e
		puts "#{e}"
	end			
	FileUtils.rm_rf "public/system/ckeditor_assets/attachments"
	FileUtils.rm_rf "public/system/ckeditor_assets/pictures"
	puts "DATABASE destroyed"
	Rake::Task["db:setup"].invoke
	puts "Base reinit"

end


desc "Create user"
task :create_user  => :environment do
	u = User.find_or_initialize_by_email("admin@developpement-durable.gouv.fr")
	u.password = 'password'
	u.roles = [:administrator]
	u.save

end

desc "Destroy database and Migrate sheets to the new appli"
task :migrate_to_new_appli  => :environment do
	#Rake::Task["db:setup"].invoke
	Dir.chdir("public") do 
		sh %{ruby start.rb}
	end
	puts "*** Pages downloaded"
	
	Rake::Task["migrate_sheets"].invoke
	puts "migrate sheets"
	Rake::Task["es:reindex:all"].invoke
	Rake::Task["create_user"].invoke
		puts "User created"
end
	


