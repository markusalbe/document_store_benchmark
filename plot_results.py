import sys 
from dash import Dash, html, dcc, callback, Output, Input
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import pandas as pd

app = Dash(__name__)

df = pd.read_csv(sys.argv[1])

def update_graph():
    layout = go.Layout(template='plotly_white')
    fig = make_subplots(rows=3, cols=6, shared_yaxes=True)
    col=0
    row=0

    for protocol in df.protocol.unique():
        dff = df[df.protocol==protocol]
        
        row+=1
        col=1
        for threads in [4,8,16]:
            per_threads_df=dff[df.threads==threads];
            for commit_frequency in per_threads_df['commit_frequency'].unique():
                trace_data = per_threads_df[per_threads_df['commit_frequency'] == commit_frequency]
                fig.add_trace( go.Bar(x=trace_data['rows_per_batch'], y=trace_data['average'], name=f"{protocol}: {threads} threads; Commit Freq.: {commit_frequency}"), row=row, col=col)
            fig.update_xaxes(type='category', row=row, col=col, title_text=protocol + " " + str(threads) + " threads", title_font_size=12)
                
            col+=1

    fig.update_layout(height=1200, width=1800, template='plotly_white', barmode='group') 
    return fig

def plot_benchmark(test):
    layout = go.Layout(template='plotly_white')
    fig = make_subplots(rows=3, cols=3, shared_yaxes=True)
    col=0
    row=0

    per_test_df = df[df.test==test];

    for protocol in per_test_df.protocol.unique():
        per_protocol_df = per_test_df[per_test_df.protocol==protocol]
    
        row+=1
        col=1
        for threads in per_protocol_df.threads.unique():
            per_threads_df=per_protocol_df[per_protocol_df.threads==threads];

            for commit_frequency in per_threads_df['commit_frequency'].unique():
                trace_data = per_threads_df[per_threads_df['commit_frequency'] == commit_frequency]
                fig.add_trace( go.Bar(x=trace_data['batch_size'], y=trace_data['time'], name=f"{protocol}: {threads} threads; Commit Freq.: {commit_frequency}",text=trace_data['time'],textposition='outside'), row=row, col=col)
            fig.update_xaxes(type='category', row=row, col=col, title_text=protocol + " " + str(threads) + " threads", title_font_size=16)
            # max_y = 80 if (test == 'read_pk_lookup' or test == 'read_sk_lookup') else 200   
            max_y = 2300;
            fig.update_yaxes(range=[0,max_y])
            col+=1

    fig.update_layout(height=1200, width=1800, template='plotly_white', barmode='group', yaxis=dict(title='Latency for 1M operations ', titlefont_size=16)) 
    return fig

# fig = update_graph()
layout_children = []
# layout_children.append( html.H1(children='Test ID: ' + df.test_uuid.unique()) )

for test in df.test.unique():
    layout_children.append( html.H2(children='Results for '+test+' by batch size', style={'textAlign':'left'}) )
    layout_children.append( dcc.Graph(id='graph-content-'+test, figure=plot_benchmark(test)) )


app.layout = html.Div(children=layout_children)


if __name__ == '__main__':
    app.run(debug=True)





# app.layout = html.Div(style={'backgroundColor': colors['background']}, children=[
#     html.H1(
#         children='Hello Dash',
#         style={
#             'textAlign': 'center',
#             'color': colors['text']
#         }
#     ),

#     html.Div(children='Dash: A web application framework for your data.', style={
#         'textAlign': 'center',
#         'color': colors['text']
#     }),

#     dcc.Graph(
#         id='example-graph-2',
#         figure=fig
#     )
# ])
