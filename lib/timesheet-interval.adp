<div id=@task_editor_id@>
<script type='text/javascript'>


// Ext.Loader.setConfig({enabled: true});
Ext.Loader.setPath('PO.model', '/sencha-core/model');
Ext.Loader.setPath('PO.store', '/sencha-core/store');
Ext.Loader.setPath('PO.class', '/sencha-core/class');
Ext.Loader.setPath('PO.view.gantt', '/sencha-core/view/gantt');
Ext.Loader.setPath('PO.controller', '/sencha-core/controller');

Ext.require([
    'Ext.data.*',
    'Ext.grid.*',
    'Ext.tree.*',
    'PO.class.CategoryStore',
    'PO.controller.StoreLoadCoordinator',
    'PO.model.timesheet.TimesheetTask',
    'PO.model.timesheet.HourInterval',
    'PO.store.timesheet.HourIntervalStore',
    'PO.store.timesheet.TaskTreeStore',
    'PO.store.timesheet.HourIntervalActivityStore'
]);


function launchTreePanel(){

    // -----------------------------------------------------------------------
    // Stores
    var hourIntervalStore = Ext.StoreManager.get('hourIntervalStore');
    var taskTreeStore = Ext.StoreManager.get('taskTreeStore');
    var ganttTreePanel = Ext.create('PO.view.gantt.GanttTreePanel', {
        width:		300,
        region:		'west',
    });

    // -----------------------------------------------------------------------
    // Renderer to display a project_id as project_name
    var hourIntervalGridProjectRenderer = function(project_id, metaData, record, rowIndex, colIndex, store, view) {
	var projectName = '#'+project_id;
	var projectNode = taskTreeStore.getNodeById(project_id);
	if (projectNode) { projectName = projectNode.get('project_name'); }
	return projectName;
    };

    var hourIntervalGrid = Ext.create('Ext.grid.Panel', {
	store: hourIntervalStore,
	columns: [
	    {text: "Project", flex: 1, dataIndex: 'project_id', renderer: hourIntervalGridProjectRenderer},
	    {text: "Start", flex: 1, dataIndex: 'interval_start', renderer: Ext.util.Format.dateRenderer('Y-m-d H:i:s') },
	    {text: "End", flex: 1, dataIndex: 'interval_end', renderer: Ext.util.Format.dateRenderer('Y-m-d H:i:s') },
	    {text: "Note", flex: 1, dataIndex: 'note'}
	],
	columnLines: true,
	enableLocking: true,
	collapsible: false,
	title: 'Expander Rows in a Collapsible Grid with lockable columns',
	emptyText: 'No data yet - please click on one of the tasks at the left',
	iconCls: 'icon-grid',
	margin: '0 0 20 0'
    });

    var ganttRightSide = Ext.create('Ext.panel.Panel', {
        title: false,
        layout: 'fit',
        region: 'center',
        collapsible: false,
        defaults: {                                                  // These defaults produce a bar to resize the timeline
            collapsible: true,
            split: true,
            bodyPadding: 0
        },
        items: [
	    hourIntervalGrid
        ]
    });


    // -----------------------------------------------------------------------
    // Outer Gantt editor jointing the two parts (TreePanel + Draw)
    var screenSize = Ext.getBody().getViewSize();    // Size calculation based on specific ]po[ layout
    var sideBarSize = Ext.get('sidebar').getSize();
    var width = screenSize.width - sideBarSize.width - 95;
    var height = screenSize.height - 280;

    Ext.define('PO.view.timesheet.HourIntervalButtonPanel', {
	extend:				'Ext.panel.Panel',
	alias:				'ganttButtonPanel',
	width: 900,
	height: 500,
	layout: 'border',
	defaults: {
	    collapsible: true,
	    split: true,
	    bodyPadding: 0
	},
	tbar: [
	    {
		text: 'OK',
		icon: '/intranet/images/navbar_default/disk.png',
		tooltip: 'Save the project to the ]po[ back-end',
		id: 'buttonSave'
	    }, {
		icon: '/intranet/images/navbar_default/folder_go.png',
		tooltip: 'Load a project from he ]po[ back-end',
		id: 'buttonLoad'
	    }, {
		xtype: 'tbseparator' 
	    }, {
		icon: '/intranet/images/navbar_default/add.png',
		tooltip: 'Add a new task',
		id: 'buttonAdd'
	    }, {
		icon: '/intranet/images/navbar_default/delete.png',
		tooltip: 'Delete a task',
		id: 'buttonDelete'
	    }, {
		xtype: 'tbseparator' 
	    }, {
		icon: '/intranet/images/navbar_default/arrow_left.png',
		tooltip: 'Reduce Indent',
		id: 'buttonReduceIndent'
	    }, {
		icon: '/intranet/images/navbar_default/arrow_right.png',
		tooltip: 'Increase Indent',
		id: 'buttonIncreaseIndent'
	    }, {
		xtype: 'tbseparator'
	    }, {
		icon: '/intranet/images/navbar_default/link_add.png',
		tooltip: 'Add dependency',
		id: 'buttonAddDependency'
	    }, {
		icon: '/intranet/images/navbar_default/link_break.png',
		tooltip: 'Break dependency',
		id: 'buttonBreakDependency'
	    }, '->' , {
		icon: '/intranet/images/navbar_default/zoom_in.png',
		tooltip: 'Zoom in time axis',
		id: 'buttonZoomIn'
	    }, {
		icon: '/intranet/images/navbar_default/zoom_out.png',
		tooltip: 'Zoom out of time axis',
		id: 'buttonZoomOut'
	    }, {
		icon: '/intranet/images/navbar_default/wrench.png',
		tooltip: 'Settings',
		id: 'buttonSettings'
	    }
	],
	renderTo: '@task_editor_id@'

    });

    var hourIntervalButtonPanel = Ext.create('PO.view.timesheet.HourIntervalButtonPanel', {
        width: width,
        height: height,
        resizable: true,				// Add handles to the panel, so the user can change size
        items: [
            ganttRightSide,
            ganttTreePanel
        ],
        renderTo: '@task_editor_id@'
    });



    // -----------------------------------------------------------------------
    // Controller for interaction between Tree and Grid
    //
    Ext.define('PO.controller.timesheet.HourIntervalController', {
	extend: 'Ext.app.Controller',

	// Variables
	debug: false,
	'renderDiv': null,
	'hourIntervalButtonPanel': null,
	'hourIntervalController': null,
	'ganttTreePanel': null,
	'ganttDrawComponent': null,
	'ganttTimeline': null,                                        // x3 time axis

	refs: [
            { ref: 'ganttTreePanel', selector: '#ganttTreePanel' }
	],
	
	init: function() {
	    var me = this;
            if (me.debug) { console.log('PO.controller.timesheet.HourIntervalController: init'); }

            this.control({
		'#buttonLoad': { click: this.onButtonLoad },
		'#buttonSave': { click: this.onButton },
		'#buttonAdd': { click: { fn: me.ganttTreePanel.onButtonAdd, scope: me.ganttTreePanel }},
		'#buttonDelete': { click: { fn: me.ganttTreePanel.onButtonDelete, scope: me.ganttTreePanel }},
		'#buttonReduceIndent': { click: { fn: me.ganttTreePanel.onButtonReduceIndent, scope: me.ganttTreePanel }},
		'#buttonIncreaseIndent': { click: { fn: me.ganttTreePanel.onButtonIncreaseIndent, scope: me.ganttTreePanel }},
		'#buttonAddDependency': { click: this.onButton },
		'#buttonBreakDependency': { click: this.onButton },
		'#buttonZoomIn': { click: this.onZoomIn },
		'#buttonZoomOut': { click: this.onZoomOut },
		'#buttonSettings': { click: this.onButton },
		scope: me.ganttTreePanel
            });

            // Listen to changes in the selction model in order to enable/disable the "delete" button.
            me.ganttTreePanel.on('selectionchange', this.onTreePanelSelectionChange, this);

            // Listen to a click into the empty space below the tree in order to add a new task
            me.ganttTreePanel.on('containerclick', me.ganttTreePanel.onContainerClick, me.ganttTreePanel);

            // Listen to special keys
            me.ganttTreePanel.on('cellkeydown', this.onCellKeyDown, me.ganttTreePanel);
            me.ganttTreePanel.on('beforecellkeydown', this.onBeforeCellKeyDown, me.ganttTreePanel);

	    // Deal with mouse move events from both surfaces
	    me.ganttTimeline.on('move', this.onTimelineMove, me);
	    me.ganttDrawComponent.on('move', this.onDrawComponentMove, me);

            return this;
	},

	onButtonLoad: function() {
            console.log('GanttButtonController.ButtonLoad');
	},

	onButtonSave: function() {
            console.log('GanttButtonController.ButtonSave');
	},

	onZoomIn: function() {
            console.log('GanttButtonController.onZoomIn');
	    this.ganttDrawComponent.onZoomIn();
	    this.ganttTimeline.onZoomIn();
	},

	onZoomOut: function() {
            console.log('GanttButtonController.onZoomOut');
	    this.ganttDrawComponent.onZoomOut();
	    this.ganttTimeline.onZoomOut();
	},

	/**
	 * The user is drag-and-dropping the Timeline around.
	 * Now update the main DrawComponent accordingly.
	 */
	onTimelineMove: function(dist) {
            // console.log('GanttButtonController.onTimelineMove: dist='+dist);
	    var axisFactor = this.ganttTimeline.axisFactor;
            this.ganttDrawComponent.translate(dist * axisFactor);	// Move the DrawComponent multiplied
	},

	/**
	 * The user is drag-and-dropping the main DrawComponent around.
	 * Now move the Timeline accordingly.
	 */
	onDrawComponentMove: function(dist) {
            console.log('GanttButtonController.onDrawComponentMove: dist='+dist);
	    var axisFactor = this.ganttTimeline.axisFactor;
            this.ganttTimeline.translate(dist / axisFactor);	// Move the Timeline by a fraction
	},

	/**
	 * Control the enabled/disabled status of the (-) (Delete) button
	 */
	onTreePanelSelectionChange: function(view, records) {
            if (this.debug) { console.log('GanttButtonController.onTreePanelSelectionChange'); }
            var buttonDelete = Ext.getCmp('buttonDelete');

            if (1 == records.length) {            // Exactly one record enabled
		var record = records[0];
		buttonDelete.setDisabled(!record.isLeaf());
            } else {                              // Zero or two or more records enabled
		buttonDelete.setDisabled(true);
            }
	},

	/**
	 * Disable default tree key actions
	 */
	onBeforeCellKeyDown: function(me, htmlTd, cellIndex, record, htmlTr, rowIndex, e, eOpts ) {
            var keyCode = e.getKey();
            var keyCtrl = e.ctrlKey;
            if (this.debug) { console.log('GanttButtonController.onBeforeCellKeyDown: code='+keyCode+', ctrl='+keyCtrl); }
            var panel = this;
            switch (keyCode) {
            case 8: 				// backspace 8
		panel.onButtonDelete();
		break;
            case 37: 				// cursor left
		if (keyCtrl) {
        	    panel.onButtonReduceIndent();
        	    return false;                   // Disable default action (fold tree)
		}
		break;
            case 39: 				// cursor right
		if (keyCtrl) {
        	    panel.onButtonIncreaseIndent();
        	    return false;                   // Disable default action (unfold tree)
		}
		break;
            case 45: 				// insert 45
		panel.onButtonAdd();
		break;
            case 46: 				// delete 46
		panel.onButtonDelete();
		break;
            }

            return true;                            // Enable default TreePanel actions for keys
	},

	/**
	 * Handle various key actions
	 */
	onCellKeyDown: function(table, htmlTd, cellIndex, record, htmlTr, rowIndex, e, eOpts) {
            var keyCode = e.getKey();
            var keyCtrl = e.ctrlKey;
	},


	/**
	 * The windows as a whole was resized
	 */
	onWindowsResize: function(width, height) {
            console.log('GanttButtonController.onWindowResize');
            var me = this;
            var sideBar = Ext.get('sidebar');				// ]po[ left side bar component
            var sideBarSize = sideBar.getSize();
	    me.onResize(sideBarSize.width);
	},

	/**
	 * The ]po[ left sideBar was resized
	 */
	onSideBarResize: function(event, el, config) {
            console.log('GanttButtonController.onSideBarResize');
            var me = this;
            var sideBar = Ext.get('sidebar');				// ]po[ left side bar component
            var sideBarSize = sideBar.getSize();

	    // We get the event _before_ the sideBar has changed it's size.
	    // So we actually need to the the oposite of the sidebar size:
	    if (sideBarSize.width > 100) {
		sideBarSize.width = -5;
	    } else {
		sideBarSize.width = 245;
	    }

	    me.onResize(sideBarSize.width);
	},

	/**
	 * Generic resizing function, called with the target width of the sideBar
	 */
	onResize: function(sideBarWidth) {
            console.log('GanttButtonController.onResize: '+sideBarWidth);
            var me = this;
            var screenSize = Ext.getBody().getViewSize();
            var height = me.hourIntervalButtonPanel.getSize().height;
            var width = screenSize.width - sideBarWidth - 75;
            me.hourIntervalButtonPanel.setSize(width, height);
	}
	
    });

    var sideBarTab = Ext.get('sideBarTab');
    var renderDiv = Ext.get('@task_editor_id@');
    var hourIntervalController = Ext.create('PO.controller.timesheet.HourIntervalController', {
        'renderDiv': renderDiv,
        'hourIntervalButtonPanel': hourIntervalButtonPanel,
        'hourIntervalController': hourIntervalController,
        'ganttTreePanel': ganttTreePanel
    });
    hourIntervalController.init(this).onLaunch(this);

    // -----------------------------------------------------------------------
    // Handle collapsable side menu
    sideBarTab.on('click', hourIntervalController.onSideBarResize, hourIntervalController);
    Ext.EventManager.onWindowResize(hourIntervalController.onWindowsResize, hourIntervalController);    // Deal with resizing the main window

};



// -----------------------------------------------------------------------
// Start the application after loading the necessary stores
//
Ext.onReady(function() {
    Ext.QuickTips.init();

    var taskTreeStore = Ext.create('PO.store.timesheet.TaskTreeStore');
    var hourIntervalStore = Ext.create('PO.store.timesheet.HourIntervalStore');

    // Use a "store coodinator" in order to launchTreePanel() only
    // if all stores have been loaded:
    var coordinator = Ext.create('PO.controller.StoreLoadCoordinator', {
        stores: [
            'hourIntervalStore', 
            'taskTreeStore'
        ],
        listeners: {
            load: function() {
                // Check if the application was launched before
                if ("boolean" == typeof this.loadedP) { return; }
                // Launch the actual application.
                launchTreePanel();
                // Mark the application as launched
                this.loadedP = true;
            }
        }
    });

    // Load stores that need parameters
    taskTreeStore.getProxy().extraParams = { project_id: @project_id@ };
    taskTreeStore.load({
        callback: function() {
            console.log('PO.store.timesheet.TaskTreeStore: loaded');
        }
    });


    // Load stores that need parameters
    hourIntervalStore.getProxy().extraParams = { project_id: @project_id@, user_id: @current_user_id@, format: 'json' };
    hourIntervalStore.load({
        callback: function() {
            console.log('PO.store.timesheet.HourIntervalStore: loaded');
        }
    });

});
</script>
</div>

