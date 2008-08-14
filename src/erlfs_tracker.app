{application, erlfs_tracker, [{mod, {erlfs_tracker, []}},
  	      		     {description, "Erlang distributed file storage system tracker."},
  	      		     {vsn, "alpha"},
	      		     {modules, [erlfs_tracker, 
			     	        erlfs_tracker_sup, 
			     	       	erlfs_tracker_svr, 
					erlfs_tracker_lib]},
			     {registered, [erlfs_tracker_svr]},
	      	             {applications, [kernel, stdlib, mnesia]}]}.