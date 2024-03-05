fn get_banegas() -> (Span<u64>, Span<u64>) {
    let times: Array<u64> = array![
        1667314458,
        1698850458,
        1730472858,
        1762008858,
        1793544858,
        1825080858,
        1856703258,
        1888239258,
        1919775258,
        1951311258,
        1982933658,
        2046005658,
        2109164058,
        2172236058,
        2235394458,
        2266930458,
        2330002458,
        2361624858,
        2393160858,
        2424696858,
        2456232858,
        2487855258,
        2582463258,
        2614085658
    ];
    let absorptions: Array<u64> = array![
        0,
        4719000,
        12584000,
        25168000,
        40898000,
        64493000,
        100672000,
        147862000,
        202917000,
        265837000,
        333476000,
        478192000,
        629200000,
        773916000,
        915486000,
        983125000,
        1108965000,
        1164020000,
        1223794000,
        1280422000,
        1335477000,
        1387386000,
        1528956000,
        1573000000
    ];
    return (times.span(), absorptions.span());
}

fn get_las_delicias() -> (Span<u64>, Span<u64>) {
    let times: Array<u64> = array![
        1667314458,
        1698850458,
        1730472858,
        1762008858,
        1793544858,
        1825080858,
        1856703258,
        1888239258,
        1919775258,
        1951311258,
        1982933658,
        2014469658,
        2046005658,
        2077541658,
        2109164058,
        2140700058,
        2172236058,
        2203772058,
        2235394458,
        2266930458,
        2298466458
    ];
    let absorptions: Array<u64> = array![
        0,
        54045000,
        126105000,
        208974000,
        317064000,
        443169000,
        587289000,
        742218000,
        907956000,
        1088106000,
        1275462000,
        1470024000,
        1686204000,
        1909590000,
        2140182000,
        2377980000,
        2630190000,
        2900415000,
        3152625000,
        3386820000,
        3603000000
    ];
    return (times.span(), absorptions.span());
}

fn get_karathuru() -> (Span<u64>, Span<u64>) {
    let times: Array<u64> = array![1717236000, 2442996000];
    let absorptions: Array<u64> = array![0, 410400000000];
    return (times.span(), absorptions.span());
}
