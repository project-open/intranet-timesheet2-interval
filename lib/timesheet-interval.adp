<div id=@task_editor_id@>
<script type='text/javascript' <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce;literal@"</if>>


// Ext.Loader.setConfig({enabled: true});
Ext.Loader.setPath('PO.model', '/sencha-core/model');
Ext.Loader.setPath('PO.store', '/sencha-core/store');
Ext.Loader.setPath('PO.class', '/sencha-core/class');
Ext.Loader.setPath('Ext.ux', '/sencha-core/ux');
Ext.Loader.setPath('PO.view', '/sencha-core/view');
Ext.Loader.setPath('PO.controller', '/sencha-core/controller');

Ext.require([
    'Ext.data.*',
    'Ext.grid.*',
    'Ext.tree.*',
    'PO.store.CategoryStore',
    'PO.controller.StoreLoadCoordinator',
    'PO.model.timesheet.TimesheetTask',
    'PO.model.timesheet.HourInterval',
    'PO.store.timesheet.HourIntervalStore',
    'PO.store.timesheet.TaskTreeStore',
    'PO.store.timesheet.HourIntervalActivityStore',
    'Ext.ux.TreeCombo'
]);


function launchTimesheetIntervalLogging(){

    // -----------------------------------------------------------------------
    // Stores
    var hourIntervalStore = Ext.StoreManager.get('hourIntervalStore');
    var taskTreeStore = Ext.StoreManager.get('taskTreeStore');
    var ganttTreePanel = Ext.create('PO.view.gantt.GanttTreePanel', {
        width: 300,
        region: 'west',
    });


    var timeEntryStore = [];
    for (var i = @time_entry_store_start_hour@; i < @time_entry_store_end_hour@; i++) {
        var ii = ""+i;
        if (ii.length == 1) { ii = "0"+i; }
        for (var m = 0; m < 60; m = m + 30 ) {
            var mm = ""+m;
            if (mm.length == 1) { mm = "0"+m; }
            timeEntryStore.push(ii + ':' + mm);
        }
    }


    // -----------------------------------------------------------------------
    // Renderer to display a project_id as project_name
    var hourIntervalGridProjectRenderer = function(project_id, metaData, record, rowIndex, colIndex, store, view) {
        var projectName = '#'+project_id;
        var projectNode = taskTreeStore.getNodeById(project_id);
        if (projectNode) { projectName = projectNode.get('project_name'); }
        return projectName;
    };

    var rowEditing = Ext.create('Ext.grid.plugin.RowEditing', {
        clicksToMoveEditor: 2,
        listeners: {
            edit: function(editor, context, eOpts) {

		// Check that the endTime is later than startTime
		var startTime = context.record.get('interval_start_time');
		var endTime = context.record.get('interval_end_time');
		if (startTime > endTime) {
		    return false;                     // Just return false - no error message
		}

                context.record.save();
            }
        }
    });

    var hourIntervalGrid = Ext.create('Ext.grid.Panel', {
        store: hourIntervalStore,
        layout: 'fit',
        region: 'center',
        plugins: [rowEditing],
        columns: [{
            text: "Project", 
            flex: 1, 
            dataIndex: 'project_id', 
            renderer: hourIntervalGridProjectRenderer,
            editor: {
                xtype: 'treecombo',
                store: taskTreeStore,
                rootVisible: false,
                displayField: 'project_name',
                valueField: 'id',
                allowBlank: false
            }
        }, {
            text: "Date",
            xtype: 'datecolumn',
            dataIndex: 'interval_date', 
            renderer: Ext.util.Format.dateRenderer('Y-m-d'),
            editor: {
                xtype: 'datefield',
                allowBlank: true,
		startDay: @week_start_day@
            }
        }, {
            text: "Start Time",
            xtype: 'templatecolumn',
            tpl: '{interval_start_time}',
            dataIndex: 'interval_start_time',
            editor: {
                xtype: 'combobox',
                triggerAction: 'all',
                selectOnTab: true,
                store: timeEntryStore
            }
        }, {
            text: "End Time", 
            dataIndex: 'interval_end_time',
            editor: {
                xtype: 'combobox',
                triggerAction: 'all',
                selectOnTab: true,
                store: timeEntryStore
            }
        }, {
            text: "Note", flex: 1, dataIndex: 'note',
            editor: { allowBlank: true }
        }],
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
            tooltip: '<%= [lang::message::lookup "" intranet-timesheet2-interval.Start_logging "Start logging"] %>',
            id: 'buttonStartLogging',
            disabled: true
        }, {
            icon: '/intranet/images/navbar_default/clock_stop.png',
            tooltip: '<%= [lang::message::lookup "" intranet-timesheet2-interval.Stop_logging "Stop logging and save"] %>',
            id: 'buttonStopLogging',
            disabled: true
        }, {
            icon: '/intranet/images/navbar_default/clock_delete.png',
            tooltip: '<%= [lang::message::lookup "" intranet-timesheet2-interval.Cancel_logging "Cancel logging"] %>',
            id: 'buttonCancelLogging',
            disabled: true
        }, {
            icon: '/intranet/images/navbar_default/add.png',
            tooltip: '<%= [lang::message::lookup "" intranet-timesheet2-interval.Manual_logging "Manual logging"] %>',
            id: 'buttonManualLogging',
            disabled: true
        }, {
            icon: '/intranet/images/navbar_default/delete.png',
            tooltip: '<%= [lang::message::lookup "" intranet-timesheet2-interval.Delete_logging "Delete entry"] %>',
            id: 'buttonDeleteLogging',
            disabled: true
        }]
    });

    // Use the button panel as a container for the task tree and the hour grid
    var hourIntervalButtonPanel = Ext.create('PO.view.timesheet.HourIntervalButtonPanel', {
        renderTo: '@task_editor_id@',
        width: width,
        height: height,
        resizable: true,					// Add handles to the panel, so the user can change size
        items: [
            hourIntervalGrid,
            ganttTreePanel
        ]
    });

    // -----------------------------------------------------------------------
    // Controller for interaction between Tree and Grid
    //
    Ext.define('PO.controller.timesheet.HourIntervalController', {
        extend: 'Ext.app.Controller',

        // Variables
        debug: true,

        'selectedTask': null,					// Task selected by selection model
        'loggingTask': null,					// contains the task on which hours are logged or null otherwise
        'loggingStartDate': null,				// contains the time when "start" was pressed or null otherwise
        'loggingInterval': null,				// the hourInterval object created when logging

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
                '#buttonCancelLogging': { click: this.onButtonCancelLogging },
                '#buttonManualLogging': { click: this.onButtonManualLogging },
                '#buttonDeleteLogging': { click: this.onButtonDeleteLogging },
                scope: me.ganttTreePanel
            });

            // Listen to changes in the selction model in order to enable/disable the start/stop buttons
            me.ganttTreePanel.on('selectionchange', this.onTreePanelSelectionChange, me);

            // Listen to a click into the empty space below the grid entries in order to start creating a new entry
            me.hourIntervalGrid.on('containerclick', this.onGridContainerClick, me);

            // Listen to changes in the selction model in order to enable/disable the start/stop buttons
            me.hourIntervalGrid.on('selectionchange', this.onGridSelectionChange, me);

            // Listen to the Grid Editor that allows to specify start- and end time
            me.hourIntervalGrid.on('edit', this.onGridEdit, me);
            me.hourIntervalGrid.on('beforeedit', this.onGridBeforeEdit, me);


            // Catch a global key strokes. This is used to abort entry with Esc.
            // For some reaons this doesn't work on the level of the HourButtonPanel, so we go for the global "window"
            Ext.EventManager.on(window, 'keydown', this.onWindowKeyDown, me);

            return this;
        },


        /*
         * Returns true if there is a single task in the GanttTreePanel
         * selected. A selected (sub-) project will return false.
         */
        ganttTreePanelLeafSelected: function() {
            var isLeaf = false;
            var selModel = ganttTreePanel.getSelectionModel();
            var records = selModel.getSelection();
            if (1 == records.length) {                  // Exactly one record needs to be enabled
                isLeaf = records[0].isLeaf();
            }
            return isLeaf;
        },

        
        /*
         * The user has double-clicked on the row editor in order to
         * manually fill in the values. This procedure automatically
         * fills in the end_time.
         */
        onGridBeforeEdit: function(editor, context, eOpts) {
            console.log('GanttButtonController.onGridBeforeEdit');
            console.log(context.record);

            var endTime = context.record.get('interval_end_time');
            if (typeof endTime === 'undefined' || "" == endTime) {
                endTime = /\d\d:\d\d/.exec(""+new Date())[0];
                context.record.set('interval_end_time', endTime);
            }
            // Return true to indicate to the editor that it's OK to edit
            return true;
        },

        // 
        onGridEdit: function(editor, context) {
            console.log('GanttButtonController.onGridEdit');
            var rec = context.record;
            
            var interval_date = rec.get('interval_date');
            var interval_start = rec.get('interval_start');
            var interval_start_time = rec.get('interval_start_time');
            var interval_end = rec.get('interval_end');
            var interval_end_time = rec.get('interval_end_time');
            if ("" == interval_start_time) { interval_start_time = null; }
            if ("" == interval_end_time) { interval_end_time = null; }

            // start == end => Delete the entry
            if (interval_start_time != null && interval_end_time != null) {
                if (interval_start_time == interval_end_time) {
                    rec.destroy();
                    return;
                }
            }


            if (interval_date != null) {
                // The interval_date has been overwritten by the editor with a Date
                var value = new Date(interval_date);
                rec.set('interval_date', Ext.Date.format(value, 'Y-m-d'));
            }

            if (interval_date != null && interval_start_time != null) {
                var value = new Date(interval_date);
                value.setHours(interval_start_time.substring(0,2));
                value.setMinutes(interval_start_time.substring(3,5));
                rec.set('interval_start', Ext.Date.format(value, 'Y-m-d H:i:s'));
            }

            if (interval_date != null && interval_end_time != null) {
                var value = new Date(interval_date);
                value.setHours(interval_end_time.substring(0,2));
                value.setMinutes(interval_end_time.substring(3,5));
                rec.set('interval_end', Ext.Date.format(value, 'Y-m-d H:i:s'));
            }

            rec.save();
            rec.commit();

        },

        // Esc (Escape) button pressed somewhere in the application window
        onWindowKeyDown: function(e) {
            var keyCode = e.getKey();
            var keyCtrl = e.ctrlKey;
            console.log('GanttButtonController.onWindowKeyDown: code='+keyCode+', ctrl='+keyCtrl);
            
            // cancel hour logging with Esc key
            if (27 == keyCode) { this.onButtonCancelLogging(); }
            if (46 == keyCode) { this.onButtonDeleteLogging(); }
        },

        // Click into the empty space below the grid entries in order to start creating a new entry
        onGridContainerClick: function() {
            console.log('GanttButtonController.GridContainerClick');
            var buttonStartLogging = Ext.getCmp('buttonStartLogging');
            var disabled = buttonStartLogging.disabled;
            if (!disabled) {
                this.onButtonStartLogging();
            }
        },

        /*
         * Start logging the time.
         * Before calling this procedure, the user must have selected a single
         * leaf in the task tree for logging hours.
         */
        onButtonStartLogging: function() {
            console.log('GanttButtonController.ButtonStartLogging');

            var buttonStartLogging = Ext.getCmp('buttonStartLogging');
            var buttonStopLogging = Ext.getCmp('buttonStopLogging');
            var buttonCancelLogging = Ext.getCmp('buttonCancelLogging');
            var buttonManualLogging = Ext.getCmp('buttonManualLogging');
            var buttonDeleteLogging = Ext.getCmp('buttonDeleteLogging');
            buttonStartLogging.disable();
            buttonStopLogging.enable();
            buttonCancelLogging.enable();
            buttonManualLogging.disable();
            buttonDeleteLogging.disable();

            rowEditing.cancelEdit();

            // Start logging
            this.loggingTask = selectedTask;
            this.loggingStartDate = new Date();

            var hourInterval = new Ext.create('PO.model.timesheet.HourInterval', {
                user_id: @current_user_id@,
                project_id: selectedTask.get('id'),
                interval_start: this.loggingStartDate,
                interval_date: this.loggingStartDate,
                interval_start_time: /\d\d:\d\d/.exec(""+new Date())[0]
            });

            // Remember the new interval, add to store and start editing
            this.loggingInterval = hourInterval;
            hourIntervalStore.add(hourInterval);
            //var rowIndex = hourIntervalStore.count() -1;
            // rowEditing.startEdit(0, 0);
        },



        /*
         * Start logging the time, for entirely manual entries.
         */
        onButtonManualLogging: function() {
            console.log('GanttButtonController.ButtonManualLogging');
            this.onButtonStartLogging();
            rowEditing.startEdit(this.loggingInterval, 0);
        },

        onButtonStopLogging: function() {
            console.log('GanttButtonController.ButtonStopLogging');
            var buttonStartLogging = Ext.getCmp('buttonStartLogging');
            var buttonStopLogging = Ext.getCmp('buttonStopLogging');
            var buttonCancelLogging = Ext.getCmp('buttonCancelLogging');
            var buttonManualLogging = Ext.getCmp('buttonManualLogging');
            buttonStartLogging.enable();
            buttonStopLogging.disable();
            buttonCancelLogging.disable();
            buttonManualLogging.enable();

            // Complete the hourInterval created when starting to log
            this.loggingInterval.set('interval_end_time', /\d\d:\d\d/.exec(""+new Date())[0]);

            // Not necesary anymore because the store is set to autosync?
            this.loggingInterval.save();
            rowEditing.cancelEdit();

            // Stop logging
            this.loggingTask = null;
            this.loggingStartDate = null;

            // Continue editing the task
            var rowIndex = hourIntervalStore.count() -1;
            rowEditing.startEdit(rowIndex, 3);
        },

        onButtonCancelLogging: function() {
            console.log('GanttButtonController.ButtonCancelLogging');
            var buttonStartLogging = Ext.getCmp('buttonStartLogging');
            var buttonStopLogging = Ext.getCmp('buttonStopLogging');
            var buttonCancelLogging = Ext.getCmp('buttonCancelLogging');
            var buttonManualLogging = Ext.getCmp('buttonManualLogging');

            buttonStartLogging.enable();
            buttonStopLogging.disable();
            buttonCancelLogging.disable();
            buttonManualLogging.enable();

            // Check if a leaf is selected in order to determine if StartLogging can be enabled
            var isLeaf = this.ganttTreePanelLeafSelected();
            buttonStartLogging.setDisabled(!isLeaf);
            buttonManualLogging.setDisabled(!isLeaf);
            
            // Delete the started line
            rowEditing.cancelEdit();
            hourIntervalStore.remove(this.loggingInterval);

            // Stop logging
            this.loggingTask = null;
            this.loggingStartDate = null;
        },

        onButtonDeleteLogging: function() {
            console.log('GanttButtonController.ButtonDeleteLogging');
            var records = hourIntervalGrid.getSelectionModel().getSelection();
            // Not logging already - enable the "start" button
            if (1 == records.length) {                  // Exactly one record enabled
                var record = records[0];
                hourIntervalStore.remove(record);
                record.destroy();
            }

            // Stop logging
            this.loggingTask = null;
            this.loggingStartDate = null;
        },

        /**
         * Control the enabled/disabled status of the Start/Stop logging buttons.
         * Skip logging hours when changing the selection.
         */
        onTreePanelSelectionChange: function(view, records) {
            if (this.debug) { console.log('GanttButtonController.onTreePanelSelectionChange'); }
            // Skip changes on the selection model while logging hours
            if (this.loggingTask) { 
                console.log('GanttButtonController.onTreePanelSelectionChange: While logging hours - skip logging');
                this.onButtonCancelLogging();
                return; 
            }
            var buttonStartLogging = Ext.getCmp('buttonStartLogging');
            var buttonManualLogging = Ext.getCmp('buttonManualLogging');
            // Not logging already - enable the "start" button
            if (1 == records.length) {					// Exactly one record enabled
                selectedTask = records[0];				// Remember which task is selected
                var isLeaf = selectedTask.isLeaf();
                buttonStartLogging.setDisabled(!isLeaf);
                buttonManualLogging.setDisabled(!isLeaf);

                // load the list of hourIntervals into the hourIntervalGrid
                var projectId = selectedTask.get('id');
                hourIntervalStore.getProxy().extraParams = { 
                    query: 'project_id in (select p.project_id from im_projects p, im_projects main_p where main_p.project_id = '+projectId+' and p.tree_sortkey between main_p.tree_sortkey and tree_right(main_p.tree_sortkey))',
                    user_id: @current_user_id@, 
                    format: 'json' 
                };

                hourIntervalStore.load({
                    callback: function() {
                        console.log('PO.store.timesheet.HourIntervalStore: loaded');
                    }
                });
            } else {							// Zero or two or more records enabled
                buttonStartLogging.setDisabled(true);
                buttonManualLogging.setDisabled(true);
            }                
        },

        /**
         * Clicking around in the grid part of the screen,
         * Enable or disable the "Delete" button
         */
        onGridSelectionChange: function(view, records) {
            if (this.debug) { console.log('GanttButtonController.onGridSelectionChange'); }
            var buttonDeleteLogging = Ext.getCmp('buttonDeleteLogging');
            buttonDeleteLogging.setDisabled(1 != records.length);
        },


        /**
         * Handle various key actions
         */
        onCellKeyDown: function(table, htmlTd, cellIndex, record, htmlTr, rowIndex, e, eOpts) {
            console.log('GanttButtonController.onCellKeyDown');
            var keyCode = e.getKey();
            var keyCtrl = e.ctrlKey;
            console.log('GanttButtonController.onCellKeyDown: code='+keyCode+', ctrl='+keyCtrl);
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

    // Testing events
    hourIntervalButtonPanel.fireEvent('keypress');



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

    // Use a "store coodinator" in order to launchTimesheetIntervalLogging() only
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
                launchTimesheetIntervalLogging();
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

