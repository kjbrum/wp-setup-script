#!/bin/bash

# Version 1.0.0

new_project="$1"

# If this isn't a WordPress install, then exit out with an error message.
if ! $(wp core is-installed); then
	echo "This is not a WordPress installation. Exiting..."
	exit 2
fi

# Just another WordPress blog (Settings->General->Tagline)
while true; do
	read -rep $'Enter a new site tagline or just hit [enter] to continue:\n' tagline
	case $tagline in
		'' )
			break;;
		* )
			wp option update blogdescription "$tagline"
			break;;
	esac
done

# Check to see if this is a new or old install
while true; do
	read -ep "Is this a new site?(y/n) " newsite
	case $newsite in
		[Yy]* )

			# Change to our custom theme
			wp theme activate $new_project

			# Create the main menu
			wp menu create "Main Menu"

			# Assign the new menu to the primary spot
			wp menu location assign main-menu primary

			# Update our admin user and create the client user
				## Update the admin user
				user_admin=$(wp user create user_admin noreply@admin.com --role=administrator --user_pass=us3r_adm1n --display_name="User Admin" --first_name=User --last_name=Admin --porcelain)
				## Create a new client user
				user_client=$(wp user create user_client noreply@client.com --role=editor --user_pass=us3r_cl13nt --display_name="User Client" --first_name=User --last_name=Client --porcelain)

				## Set the color scheme for both users
				# wp user meta update $user_admin admin_color colorscheme
				# wp user meta update $user_client admin_color colorscheme

				## Delete the default admin and reassign posts to user_admin
				wp user delete 1 --reassign=$user_admin

			# Activate common plugins
				## Activate Gravity Forms
				# wp plugin activate gravityforms
				## Activate Advanced Custom Fields
				# wp plugin activate advanced-custom-fields-pro

			# Set up the front page. Home page is for showing latest blog posts
				## Set the front page to a static page (Settings->Reading->Front page displays)
				wp option update show_on_front 'page'
					### Rename the default page to Front Page. Change its slug to front-page. Set its content to a space.
					wp post update 2 --post_title='Home' --post_name='home' --post_content=' '
					### The default WordPress page is post ID 2. Set post 2 to the front page (Settings->Reading->Front page displays)
					wp option update page_on_front 2
					### Add the home page to the main menu
					wp menu item add-post main-menu 2

			# Check if the site has a blog
			while true; do
				read -ep "Does the site have a blog?(y/n): " blog
				case $blog in
					[Nn]* )
						break;;
					[Yy]* )
						# Set up the home page at /blog. The home page is for showing the latest blog posts, and is not a front page.
							## Create the page, save the output id to a variable
							blog_page=$(wp post create --post_type=page --post_status=publish --post_title='Blog' --post_name='blog' --porcelain)
							## Set the posts page to the created page
							wp option update page_for_posts $blog_page
							## Add the blog page to the main menu
							wp menu item add-post main-menu $blog_page
						# Delete the first post, Hello world!
							## The default WordPress first post is post ID 1. Delete the post with ID 1. Have it bypass the trash (--force)
							wp post delete 1 --force

							# Add blog posts if wanted
							while true; do
								read -ep "How many blog posts would you like to add?: " blog_num
								case $blog_num in
									0 )
										break;;
									* )
										## Add posts with plenty of content from http://loripsum.net
										curl http://loripsum.net/api/10/medium/decorate/link/ul/ol/dl/bq/headers/prude | wp post generate --post_content --post_author=user_admin --count=$blog_num
										## Check to see if they want to add featured images
										while true; do
											read -ep "Would you like to add featured images to these posts? (WARNING: lots of posts can take a while) (y/n): " featured_images
											case $featured_images in
												[Nn]* )
													break;;
												[Yy]* )
													### Get all posts and add featured image
													OIFS=$IFS
													IFS=' '
													all_posts=$(wp post list --post_type=post --format=ids)
													for post_id in $all_posts; do
														wp media import https://placeimg.com/1200/700/placeholder.png --post_id=$post_id --title="Placeholder images are wonderful!" --featured_image
													done
													IFS=$OIFS
													break;;
											esac
										done
										break;;
								esac
							done
						break;;
				esac
			done

			# Add some pages to our new blog
			while true; do
				read -rep $'Type a comma separated list of pages to create (exclude "Home & Blog", prefix sub-pages with "-"), or just hit [enter]:\n' pages
				case $pages in
					'' )
						break;;
					* )
						OIFS=$IFS
						IFS=','
						for page in $pages; do
							## Check if current page is suppose to be a sub-page
							if [[ $page == -* ]]
							then
								## Remove the - from the page title
								title=${page#*-}
								## Create sub-pages
								page_id=$(wp post create --post_type=page --post_status=publish --post_title=$title --post_name=$title --post_parent=$parent --porcelain)
								## Add sub-page to main menu under it's parent
								wp menu item add-post main-menu $page_id --parent-id=$parent_menu
							else
								## Create top-level pages
								parent=$(wp post create --post_type=page --post_status=publish --post_title=$page --post_name=$page --porcelain)
								## Add page to main menu
								parent_menu=$(wp menu item add-post main-menu $parent --porcelain)
							fi
						done
						IFS=$OIFS
						break;;
				esac
			done
			break;;
		[Nn]* )
			break;;
	esac
done

# Turn off registration (Settings->General->Anyone can register)
wp option update users_can_register 0

# Kill emoticons (Settings->Writing->Convert emoticons)
wp option update use_smilies 0

# Set blog to public visibility (Settings->Reading->Search Engine Visibility)
wp option update blog_public 1

# Kill all comments
	## Default article settings (Settings->Discussion->Default article settings)
		### Attempt to notify any blogs linked to from the article
		wp option update default_pingback_flag 0
		### Allow link notifications from other blogs (pingbacks and trackbacks)
		wp option update default_ping_status closed
		### Allow people to post comments on new articles
		wp option update default_comment_status closed
	## Other comment settings (Settings->Discussion->Other comment settings)
		### Comment author must fill out name and e-mail
		wp option update require_name_email 1
		### Users must be registered and logged in to comment
		wp option update comment_registration 1
	## Don't email me about comments (Settings->Discussion->E-mail me whenever)
		### Anyone posts a comment
		wp option update comments_notify 0
		### A comment is held for moderation
		wp option update moderation_notify 0
	## Make it so a user can never comment (Settings->Discussion->Before a comment appears)
		### An administrator must always approve the comment
		wp option update comment_moderation 1
		### Comment author must have a previously approved comment
		wp option update comment_whitelist 1

# Set the permalink structure to Month and Name. (Settings->Permalinks)
# Remember that this is for blog posts (posts with the post type post)
# By changing this from default it enables %post_name% for pages
wp rewrite structure '%year%/%monthnum%/%postname%/'
# rules flushed automatically by wp-cli

# Update timezone
wp option update timezone_string 'America/Chicago'

# Get any plugin updates specified in composer.json
composer update