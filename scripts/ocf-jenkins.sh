#!/bin/sh

: ${OCF_FUNCTIONS_DIR=${OCF_ROOT}/lib/heartbeat}
. ${OCF_FUNCTIONS_DIR}/ocf-shellfuncs

meta_data() {
  cat <<END
<?xml version="1.0"?>
<!DOCTYPE resource-agent SYSTEM "ra-api-1.dtd">
<resource-agent name="Jenkins">
<version>1.0</version>

<longdesc lang="en">
This is a Jenkins Resource Agent. It does absolutely nothing except
keep track of whether its running or not.
Its purpose in life is for testing and to serve as a template for RA writers.

NB: Please pay attention to the timeouts specified in the actions
section below. They should be meaningful for the kind of resource
the agent manages. They should be the minimum advised timeouts,
but they shouldn't/cannot cover _all_ possible resource
instances. So, try to be neither overly generous nor too stingy,
but moderate. The minimum timeouts should never be below 10 seconds.
</longdesc>
<shortdesc lang="en">Example stateless resource agent</shortdesc>

<parameters>
<parameter name="state" unique="1">
<longdesc lang="en">
Location to store the resource state in.
</longdesc>
<shortdesc lang="en">State file</shortdesc>
<content type="string" default="${HA_RSCTMP}/Jenkins-${OCF_RESOURCE_INSTANCE}.state" />
</parameter>

</parameters>

<actions>
<action name="start"        timeout="20" />
<action name="stop"         timeout="20" />
<action name="monitor"      timeout="20" interval="10" depth="0" />
<action name="reload"       timeout="20" />
<action name="migrate_to"   timeout="20" />
<action name="migrate_from" timeout="20" />
<action name="meta-data"    timeout="5" />
<action name="validate-all"   timeout="20" />
</actions>
</resource-agent>
END
}

#######################################################################

jenkins_usage() {
  cat <<END
usage: $0 {start|stop|monitor|migrate_to|migrate_from|validate-all|meta-data}

Expects to have a fully populated OCF RA-compliant environment set.
END
}

jenkins_start() {
    jenkins_monitor
    systemctl restart jenkins
    if [ $? =  $OCF_SUCCESS ]; then
  return $OCF_SUCCESS
    fi
    touch ${OCF_RESKEY_state}
}

jenkins_stop() {
    jenkins_monitor
    if [ $? =  $OCF_SUCCESS ]; then
  rm ${OCF_RESKEY_state}
    fi
    return $OCF_SUCCESS
}

jenkins_monitor() {
  if [ -f ${OCF_RESKEY_state} ]; then
      return $OCF_SUCCESS
  fi
  if false ; then
    return $OCF_ERR_GENERIC
  fi

  if ! ocf_is_probe && [ "$__OCF_ACTION" = "monitor" ]; then
    ocf_exit_reason "No process state file found"
  fi
  return $OCF_NOT_RUNNING
}

jenkins_validate() {
    state_dir=`dirname "$OCF_RESKEY_state"`
    touch "$state_dir/$$"
    if [ $? != 0 ]; then
  ocf_exit_reason "State file \"$OCF_RESKEY_state\" is not writable"
  return $OCF_ERR_ARGS
    fi
    rm "$state_dir/$$"

    return $OCF_SUCCESS
}

: ${OCF_RESKEY_state=${HA_RSCTMP}/Jenkins-${OCF_RESOURCE_INSTANCE}.state}


case $__OCF_ACTION in
meta-data)  meta_data
    exit $OCF_SUCCESS
    ;;
start)    jenkins_start;;
stop)   jenkins_stop;;
monitor)  jenkins_monitor;;
migrate_to) ocf_log info "Migrating ${OCF_RESOURCE_INSTANCE} to ${OCF_RESKEY_CRM_meta_migrate_target}."
          jenkins_stop
    ;;
migrate_from) ocf_log info "Migrating ${OCF_RESOURCE_INSTANCE} from ${OCF_RESKEY_CRM_meta_migrate_source}."
          jenkins_start
    ;;
reload)   ocf_log info "Reloading ${OCF_RESOURCE_INSTANCE} ..."
    ;;
validate-all) jenkins_validate;;
usage|help) jenkins_usage
    exit $OCF_SUCCESS
    ;;
*)    jenkins_usage
    exit $OCF_ERR_UNIMPLEMENTED
    ;;
esac
rc=$?
ocf_log debug "${OCF_RESOURCE_INSTANCE} $__OCF_ACTION : $rc"
exit $rc
