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

    // Stores
    var hourIntervalStore = Ext.StoreManager.get('hourIntervalStore');
    var taskTreeStore = Ext.StoreManager.get('taskTreeStore');
    var ganttTreePanel = Ext.create('PO.view.gantt.GanttTreePanel', {
        width:		300,
        region:		'west',
    });

    // Renderer to display a project_id as project_name
    var projectRenderer = function(project_id, metaData, record, rowIndex, colIndex, store, view) {
	var projectName = '#'+project_id;
	var projectNode = taskTreeStore.getNodeById(project_id);
	if (projectNode) { projectName = projectNode.get('project_name'); }
	return projectName;
    };

    var hourIntervalGrid = Ext.create('Ext.grid.Panel', {
	store: hourIntervalStore,
	columns: [
	    {text: "Project", flex: 1, dataIndex: 'project_id', renderer: projectRenderer},
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


    // Outer Gantt editor jointing the two parts (TreePanel + Draw)
    var screenSize = Ext.getBody().getViewSize();    // Size calculation based on specific ]po[ layout
    var sideBarSize = Ext.get('sidebar').getSize();
    var width = screenSize.width - sideBarSize.width - 95;
    var height = screenSize.height - 280;
    var ganttEditor = Ext.create('PO.view.gantt.GanttButtonPanel', {
        width: width,
        height: height,
        resizable: true,				// Add handles to the panel, so the user can change size
        items: [
            ganttRightSide,
            ganttTreePanel
        ],
        renderTo: '@task_editor_id@'
    });

    // Initiate controller
    var sideBarTab = Ext.get('sideBarTab');
    var renderDiv = Ext.get('@task_editor_id@');
    var ganttButtonController = Ext.create('PO.controller.gantt.GanttButtonController', {
        'renderDiv': renderDiv,
        'ganttEditor': ganttEditor,
        'ganttButtonController': ganttButtonController,
        'ganttTreePanel': ganttTreePanel
    });
    ganttButtonController.init(this).onLaunch(this);

    // Handle collapsable side menu
    sideBarTab.on('click', ganttButtonController.onSideBarResize, ganttButtonController);
    Ext.EventManager.onWindowResize(ganttButtonController.onWindowsResize, ganttButtonController);    // Deal with resizing the main window

};



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
    // hourIntervalStore.getProxy().extraParams = { project_id: 0, user_id: 0, format: 'json' };
    hourIntervalStore.load({
        callback: function() {
            console.log('PO.store.timesheet.HourIntervalStore: loaded');
        }
    });

});
</script>
</div>

