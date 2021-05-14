function viewDataFrame(df, nbrows=10)
    names_ = names(df)
    thead = html_tr([html_th(col) for col in names_])
    tbody = map(1:min(nbrows, size(df, 1))) do row
        html_tr([html_td(string(df[row, col])) for col in names_])
    end
    return dbc_table(
        [html_thead(thead), html_tbody(tbody)];
        bordered=true,
        hover=true,
        striped=true,
        responsive=true,
    )
end

function generate_table(dataframe, max_rows=10)
    return dbc_table(
        [
            html_thead(html_tr([html_th(col) for col in names(dataframe)])),
            html_tbody([
                html_tr([html_td(dataframe[r, c]) for c in names(dataframe)]) for
                r in 1:min(size(dataframe, 1), max_rows)
            ]),
        ];
        bordered=true,
        hover=true,
        striped=true,
        responsive=true,
    )
end
