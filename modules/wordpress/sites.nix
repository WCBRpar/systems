
{ lib, ... }: 

{
  sites = lib.mkOptions {
      "RED" = {
        sumdomain = "";
        domain = "redcom.digital";
        organization = "wcbrpar.com";
        type = {
          "wordpress" = {
            plugins = [
  	      "co-authors-plus"
  	      "google-site-kit"
  	    ];
	    themes = [
	      "astra"
	      "twentytwentythree"
	    ];
	    languages = "pt_BR";
	  };
        };
      };
    };
 }


# Quando era JSON!
# 
# {
#   "sites": {
#     "redcom.digital": {
#       "subdomain": "",
#       "domain": "redcom.digital",
#       "organization": "wcbrpar.com",
#       "type": {
#         "type": "wordpress",
#         "plugins": [
#           "co-authors-plus",
#           "google-site-kit"
#         ],
#         "themes": [
#           "astra",
#           "twentytwentythree"
#         ],
#         "languages": "pt_BR"
#       }
#     }
#   }
# }
