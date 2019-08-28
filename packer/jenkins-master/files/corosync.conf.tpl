totem {
    version: 2
    secauth: off
    rrp_mode:active
    cluster_name: $CLUSTER_NAME
    transport: udpu
    token: 17000
}

nodelist {
    $NODELIST
}

quorum {
    provider: corosync_votequorum
    expected_votes: $CLUSTER_SIZE
}
