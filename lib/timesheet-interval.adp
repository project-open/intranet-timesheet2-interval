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
        width: 300,
        region: 'west',
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
	layout: 'fit',
        region: 'center',

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
	header: false,
	emptyText: 'No data yet - please click on one of the tasks at the left',
	iconCls: 'icon-grid',
	margin: '0 0 20 0'
    });

    // -----------------------------------------------------------------------
    // Outer Gantt editor jointing the two parts (TreePanel + Grid)
    var screenSize = Ext.getBody().getViewSize();    // Size calculation based on specific ]po[ layout
    var sideBarSize = Ext.get('sidebar').getSize();
    var width = screenSize.width - sideBarSize.width - 95;
    var height = screenSize.height - 280;

    Ext.define('PO.view.timesheet.HourIntervalButtonPanel', {
	extend: 'Ext.panel.Panel',
	alias: 'ganttButtonPanel',
	width: 900,
	height: 500,
	layout: 'border',
	defaults: {
	    collapsible: true,
	    split: true,
	    bodyPadding: 0
	},
	tbar: [{
	    icon: '/intranet/images/navbar_default/clock_go.png',
	    tooltip: 'Start logging',
	    id: 'buttonStartLogging',
	    disabled: true
	}, {
	    icon: '/intranet/images/navbar_default/clock_stop.png',
	    tooltip: 'Stop logging',
	    id: 'buttonStopLogging',
	    disabled: true
	}]
    });

    // Use the button panel as a container for the task tree and the hour grid
    var hourIntervalButtonPanel = Ext.create('PO.view.timesheet.HourIntervalButtonPanel', {
        width: width,
        height: height,
        resizable: true,				// Add handles to the panel, so the user can change size
        items: [
            hourIntervalGrid,
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
	debug: true,

	'selectedTask': null,			// Task selected by selection model
	'loggingTask': null,			// contains the task on which hours are logged or null otherwise
	'loggingStartDate': null,			// contains the time when "start" was pressed or null otherwise

	// Parameters
	'renderDiv': null,
	'hourIntervalButtonPanel': null,
	'hourIntervalController': null,
	'hourIntervalGrid': null,
	'ganttTreePanel': null,

	// Setup the various listeners so that everything gets concentrated here on
	// this controller.
	init: function() {
	    var me = this;
            if (me.debug) { console.log('PO.controller.timesheet.HourIntervalController: init'); }

            this.control({
		'#buttonStartLogging': { click: this.onButtonStartLogging },
		'#buttonStopLogging': { click: this.onButtonStopLogging },
		scope: me.ganttTreePanel
            });

            // Listen to changes in the selction model in order to enable/disable the start/stop buttons
            me.ganttTreePanel.on('selectionchange', this.onTreePanelSelectionChange, me);

            // Listen to a click into the empty space below the tree in order to add a new task
            me.ganttTreePanel.on('containerclick', me.ganttTreePanel.onContainerClick, me.ganttTreePanel);

            return this;
	},

	onButtonStartLogging: function() {
            console.log('GanttButtonController.ButtonStartLogging');
            var buttonStartLogging = Ext.getCmp('buttonStartLogging');
            var buttonStopLogging = Ext.getCmp('buttonStopLogging');
	    buttonStartLogging.disable();
	    buttonStopLogging.enable();

	    // Start logging
	    this.loggingTask = selectedTask;
	    this.loggingStartTime = new Date();
	},

	onButtonStopLogging: function() {
            console.log('GanttButtonController.ButtonStopLogging');
            var buttonStartLogging = Ext.getCmp('buttonStartLogging');
            var buttonStopLogging = Ext.getCmp('buttonStopLogging');
	    buttonStartLogging.disable();
	    buttonStopLogging.disable();

	    // Stop logging
	    this.loggingTask = null;
	    this.loggingStartTime = null;
	},

	/**
	 * Control the enabled/disabled status of the Start/Stop logging buttons
	 */
	onTreePanelSelectionChange: function(view, records) {
            if (this.debug) { console.log('GanttButtonController.onTreePanelSelectionChange'); }

	    // Skip changes on the selection model while logging hours
	    if (this.loggingTask) { return; }

            var buttonStartLogging = Ext.getCmp('buttonStartLogging');

	    // Not logging already - enable the "start" button
	    if (1 == records.length) {			// Exactly one record enabled
		var record = records[0];
		selectedTask = record;			// Remember which task is selected
		var isLeaf = record.isLeaf();
		buttonStartLogging.setDisabled(!isLeaf);
	    } else {					// Zero or two or more records enabled
		buttonStartLogging.setDisabled(true);
	    }		
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
    var hourIntervalController = Ext.create('PO.controller.timesheet.HourIntervalController', {
        'hourIntervalButtonPanel': hourIntervalButtonPanel,
        'hourIntervalController': hourIntervalController,
	'hourIntervalGrid': hourIntervalGrid,
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

